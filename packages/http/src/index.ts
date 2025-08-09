export type ProblemDetails = Readonly<{
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  details?: { code: string; fields?: Record<string, string> };
}>;

export function problem(p: ProblemDetails, headers: Record<string, string> = {}) {
  return {
    status: p.status,
    headers: { 'content-type': 'application/problem+json', ...headers },
    body: p
  } as const;
}


