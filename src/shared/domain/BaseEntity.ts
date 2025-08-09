export abstract class BaseEntity<TProps extends object> {
  constructor(public readonly id: string, public readonly props: TProps) {}
}



