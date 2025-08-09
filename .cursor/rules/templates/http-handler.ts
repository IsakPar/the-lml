// Framework-agnostic HTTP handler template

export type HttpRequest = Readonly<{
  method: string;
  path: string;
  headers: Record<string, string | undefined>;
  query: Record<string, string | undefined>;
  params: Record<string, string | undefined>;
  body: unknown;
}>;

export type HttpResponse = Readonly<{
  status: number;
  headers?: Record<string, string>;
  body?: unknown;
}>;

export type ProblemDetails = Readonly<{
  type: string; // stable URI for machine parsing
  title: string; // human summary
  status: number;
  detail?: string;
  instance?: string;
  details?: { code: string; fields?: Record<string, string> };
}>;

export function problem(
  p: ProblemDetails,
  headers: Record<string, string> = {}
): HttpResponse {
  return {
    status: p.status,
    headers: { "content-type": "application/problem+json", ...headers },
    body: p,
  };
}

export type CreateHandlerDeps = Readonly<{
  correlationId: () => string;
}>;

export function createExampleHandler(
  deps: CreateHandlerDeps,
  execute: (input: { exampleField: string }) => Promise<
    | { ok: true; value: { id: string; createdAtIso: string } }
    | { ok: false; error: { code: string; message: string } }
  >
) {
  return async function handler(req: HttpRequest): Promise<HttpResponse> {
    const correlationId = req.headers["x-correlation-id"] ?? deps.correlationId();

    if (req.method !== "POST") {
      return problem(
        {
          type: "https://example.com/problems/method-not-allowed",
          title: "Method not allowed",
          status: 405,
          detail: "Expected POST",
          details: { code: "METHOD_NOT_ALLOWED" },
        },
        { "x-correlation-id": String(correlationId) }
      );
    }

    const body = req.body as Partial<{ exampleField: string }>;
    const exampleField = (body?.exampleField ?? "").toString();

    const result = await execute({ exampleField });
    if (!result.ok) {
      const map: Record<string, ProblemDetails> = {
        VALIDATION_ERROR: {
          type: "https://example.com/problems/validation",
          title: "Validation error",
          status: 400,
          detail: result.error.message,
          details: { code: result.error.code },
        },
        CONFLICT: {
          type: "https://example.com/problems/conflict",
          title: "Conflict",
          status: 409,
          detail: result.error.message,
          details: { code: result.error.code },
        },
        UNKNOWN: {
          type: "https://example.com/problems/unknown",
          title: "Unknown error",
          status: 500,
          detail: result.error.message,
          details: { code: result.error.code },
        },
      };
      const pd = map[result.error.code] ?? map.UNKNOWN;
      return problem(pd, { "x-correlation-id": String(correlationId) });
    }

    return {
      status: 201,
      headers: {
        "content-type": "application/json",
        "x-correlation-id": String(correlationId),
      },
      body: {
        id: result.value.id,
        createdAtIso: result.value.createdAtIso,
      },
    };
  };
}


