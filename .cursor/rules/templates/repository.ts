// Application-layer port template for persistence

export type Transaction<T> = Promise<T>;

export interface TransactionManager {
  runInTransaction<T>(operation: () => Promise<T>): Transaction<T>;
}

export type EntityId = string;

export type ExampleEntity = Readonly<{
  id: EntityId;
  exampleField: string;
  version: number;
}>;

export interface ExampleRepository {
  findById(id: EntityId): Promise<ExampleEntity | null>;
  insert(entity: ExampleEntity): Promise<void>;
  updateIfVersionMatches(
    id: EntityId,
    expectedVersion: number,
    patch: Partial<Pick<ExampleEntity, "exampleField">>
  ): Promise<boolean>; // returns true if updated
}


