// Application-layer use case template (framework-free)

export type Result<Ok, Err> =
  | { ok: true; value: Ok }
  | { ok: false; error: Err };

export type UseCaseClock = {
  now: () => Date;
};

export type UseCaseIdGenerator = {
  generateId: () => string;
};

export type CreateUseCaseDeps = Readonly<{
  clock: UseCaseClock;
  idGen: UseCaseIdGenerator;
}>;

export type ExampleInputDto = Readonly<{
  exampleField: string;
}>;

export type ExampleOutputDto = Readonly<{
  id: string;
  createdAtIso: string;
}>;

export type ExampleError =
  | { code: "VALIDATION_ERROR"; message: string }
  | { code: "CONFLICT"; message: string }
  | { code: "UNKNOWN"; message: string };

export function createExampleUseCase(deps: CreateUseCaseDeps) {
  return async function execute(
    input: ExampleInputDto
  ): Promise<Result<ExampleOutputDto, ExampleError>> {
    if (!input.exampleField || input.exampleField.trim().length === 0) {
      return {
        ok: false,
        error: { code: "VALIDATION_ERROR", message: "exampleField is required" },
      };
    }

    const id = deps.idGen.generateId();
    const createdAtIso = deps.clock.now().toISOString();

    return { ok: true, value: { id, createdAtIso } };
  };
}

export type ExampleUseCase = ReturnType<typeof createExampleUseCase>;


