import { Result } from '@thankful/result';

/**
 * Billing Configuration value object
 * Encapsulates all billing-related settings for a venue
 */
export interface BillingConfigurationData {
  plan: BillingPlan;
  pricing: BillingPricing;
  payment: BillingPayment;
  limits?: BillingLimits;
  discounts?: BillingDiscount[];
}

export interface BillingPricing {
  feePercentage: number; // Platform fee percentage (e.g., 2.5%)
  monthlyFee: number; // Fixed monthly fee
  transactionFee: number; // Per-transaction fee
  setupFee?: number; // One-time setup fee
  currency: string; // ISO currency code
}

export interface BillingPayment {
  billingCycle: BillingCycle;
  paymentMethod: PaymentMethod;
  billingDay?: number; // Day of month for billing (1-31)
  gracePeriodDays: number;
  autoRenewal: boolean;
  invoiceEmail: string;
  taxId?: string;
}

export interface BillingLimits {
  maxTransactionsPerMonth?: number;
  maxRevenuePerMonth?: number;
  maxRefundsPerMonth?: number;
  overagePolicy: OveragePolicy;
}

export interface BillingDiscount {
  id: string;
  name: string;
  type: DiscountType;
  value: number; // Percentage or fixed amount
  validFrom: Date;
  validUntil?: Date;
  conditions?: Record<string, any>;
}

export enum BillingPlan {
  STARTER = 'starter',
  STANDARD = 'standard',
  PREMIUM = 'premium',
  ENTERPRISE = 'enterprise',
  CUSTOM = 'custom'
}

export enum BillingCycle {
  MONTHLY = 'monthly',
  QUARTERLY = 'quarterly',
  YEARLY = 'yearly'
}

export enum PaymentMethod {
  CREDIT_CARD = 'credit_card',
  BANK_TRANSFER = 'bank_transfer',
  INVOICE = 'invoice',
  ACH = 'ach'
}

export enum OveragePolicy {
  BLOCK = 'block',
  CHARGE = 'charge',
  NOTIFY = 'notify'
}

export enum DiscountType {
  PERCENTAGE = 'percentage',
  FIXED_AMOUNT = 'fixed_amount'
}

export class BillingConfiguration {
  private constructor(
    private readonly _data: BillingConfigurationData
  ) {}

  public static create(data: BillingConfigurationData): Result<BillingConfiguration, string> {
    const validation = BillingConfiguration.validate(data);
    if (!validation.success) {
      return validation;
    }

    return Result.success(new BillingConfiguration(data));
  }

  public static createDefault(): BillingConfiguration {
    const defaultData: BillingConfigurationData = {
      plan: BillingPlan.STANDARD,
      pricing: {
        feePercentage: 2.5,
        monthlyFee: 99.00,
        transactionFee: 0.30,
        currency: 'USD'
      },
      payment: {
        billingCycle: BillingCycle.MONTHLY,
        paymentMethod: PaymentMethod.CREDIT_CARD,
        gracePeriodDays: 7,
        autoRenewal: true,
        invoiceEmail: ''
      },
      limits: {
        overagePolicy: OveragePolicy.NOTIFY
      }
    };

    return new BillingConfiguration(defaultData);
  }

  private static validate(data: BillingConfigurationData): Result<void, string> {
    // Validate plan
    if (!data.plan) {
      return Result.failure('Billing plan is required');
    }

    // Validate pricing
    if (!data.pricing) {
      return Result.failure('Pricing configuration is required');
    }

    if (data.pricing.feePercentage < 0 || data.pricing.feePercentage > 100) {
      return Result.failure('Fee percentage must be between 0 and 100');
    }

    if (data.pricing.monthlyFee < 0) {
      return Result.failure('Monthly fee cannot be negative');
    }

    if (data.pricing.transactionFee < 0) {
      return Result.failure('Transaction fee cannot be negative');
    }

    if (!data.pricing.currency || data.pricing.currency.length !== 3) {
      return Result.failure('Valid ISO currency code is required');
    }

    // Validate payment
    if (!data.payment) {
      return Result.failure('Payment configuration is required');
    }

    if (data.payment.gracePeriodDays < 0) {
      return Result.failure('Grace period days cannot be negative');
    }

    if (!data.payment.invoiceEmail || !this.isValidEmail(data.payment.invoiceEmail)) {
      return Result.failure('Valid invoice email is required');
    }

    if (data.payment.billingDay && (data.payment.billingDay < 1 || data.payment.billingDay > 31)) {
      return Result.failure('Billing day must be between 1 and 31');
    }

    // Validate limits if provided
    if (data.limits) {
      if (data.limits.maxTransactionsPerMonth && data.limits.maxTransactionsPerMonth < 1) {
        return Result.failure('Max transactions per month must be at least 1');
      }

      if (data.limits.maxRevenuePerMonth && data.limits.maxRevenuePerMonth < 0) {
        return Result.failure('Max revenue per month cannot be negative');
      }
    }

    // Validate discounts if provided
    if (data.discounts) {
      for (const discount of data.discounts) {
        if (!discount.id || !discount.name) {
          return Result.failure('Discount ID and name are required');
        }

        if (discount.type === DiscountType.PERCENTAGE && (discount.value < 0 || discount.value > 100)) {
          return Result.failure('Percentage discount must be between 0 and 100');
        }

        if (discount.type === DiscountType.FIXED_AMOUNT && discount.value < 0) {
          return Result.failure('Fixed amount discount cannot be negative');
        }
      }
    }

    return Result.success(undefined);
  }

  private static isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  /**
   * Calculate monthly cost for a venue
   */
  public calculateMonthlyCost(
    transactionCount: number,
    totalRevenue: number
  ): BillingCalculation {
    const baseFee = this._data.pricing.monthlyFee;
    const transactionFees = transactionCount * this._data.pricing.transactionFee;
    const percentageFees = totalRevenue * (this._data.pricing.feePercentage / 100);
    
    const subtotal = baseFee + transactionFees + percentageFees;
    const discountAmount = this.calculateDiscountAmount(subtotal);
    const total = subtotal - discountAmount;

    return {
      baseFee,
      transactionFees,
      percentageFees,
      subtotal,
      discountAmount,
      total,
      currency: this._data.pricing.currency,
      breakdown: {
        transactionCount,
        totalRevenue,
        feePercentage: this._data.pricing.feePercentage,
        transactionFee: this._data.pricing.transactionFee
      }
    };
  }

  /**
   * Check if usage exceeds limits
   */
  public checkLimits(usage: BillingUsage): BillingLimitCheck {
    const violations: string[] = [];
    
    if (this._data.limits) {
      if (this._data.limits.maxTransactionsPerMonth && 
          usage.transactionCount > this._data.limits.maxTransactionsPerMonth) {
        violations.push('Max transactions per month exceeded');
      }

      if (this._data.limits.maxRevenuePerMonth && 
          usage.totalRevenue > this._data.limits.maxRevenuePerMonth) {
        violations.push('Max revenue per month exceeded');
      }

      if (this._data.limits.maxRefundsPerMonth && 
          usage.refundCount > this._data.limits.maxRefundsPerMonth) {
        violations.push('Max refunds per month exceeded');
      }
    }

    return {
      hasViolations: violations.length > 0,
      violations,
      overagePolicy: this._data.limits?.overagePolicy || OveragePolicy.NOTIFY
    };
  }

  /**
   * Apply discount to billing
   */
  public applyDiscount(discountId: string): Result<BillingConfiguration, string> {
    const discount = this._data.discounts?.find(d => d.id === discountId);
    if (!discount) {
      return Result.failure('Discount not found');
    }

    const now = new Date();
    if (discount.validFrom > now || (discount.validUntil && discount.validUntil < now)) {
      return Result.failure('Discount is not valid for current date');
    }

    // Discount is already applied if it exists in the configuration
    return Result.success(this);
  }

  /**
   * Update pricing
   */
  public updatePricing(pricing: Partial<BillingPricing>): Result<BillingConfiguration, string> {
    const newPricing = { ...this._data.pricing, ...pricing };
    const newData = { ...this._data, pricing: newPricing };
    
    return BillingConfiguration.create(newData);
  }

  /**
   * Update payment configuration
   */
  public updatePayment(payment: Partial<BillingPayment>): Result<BillingConfiguration, string> {
    const newPayment = { ...this._data.payment, ...payment };
    const newData = { ...this._data, payment: newPayment };
    
    return BillingConfiguration.create(newData);
  }

  private calculateDiscountAmount(subtotal: number): number {
    if (!this._data.discounts) {
      return 0;
    }

    const now = new Date();
    let totalDiscount = 0;

    for (const discount of this._data.discounts) {
      if (discount.validFrom <= now && (!discount.validUntil || discount.validUntil >= now)) {
        if (discount.type === DiscountType.PERCENTAGE) {
          totalDiscount += subtotal * (discount.value / 100);
        } else {
          totalDiscount += discount.value;
        }
      }
    }

    return Math.min(totalDiscount, subtotal); // Don't exceed subtotal
  }

  /**
   * Getters
   */
  public get data(): BillingConfigurationData {
    return { ...this._data };
  }

  public get plan(): BillingPlan {
    return this._data.plan;
  }

  public get pricing(): BillingPricing {
    return { ...this._data.pricing };
  }

  public get payment(): BillingPayment {
    return { ...this._data.payment };
  }

  public get limits(): BillingLimits | undefined {
    return this._data.limits ? { ...this._data.limits } : undefined;
  }

  /**
   * Serialization
   */
  public toJSON(): BillingConfigurationData {
    return this._data;
  }
}

/**
 * Supporting interfaces
 */
export interface BillingCalculation {
  baseFee: number;
  transactionFees: number;
  percentageFees: number;
  subtotal: number;
  discountAmount: number;
  total: number;
  currency: string;
  breakdown: {
    transactionCount: number;
    totalRevenue: number;
    feePercentage: number;
    transactionFee: number;
  };
}

export interface BillingUsage {
  transactionCount: number;
  totalRevenue: number;
  refundCount: number;
  refundAmount: number;
}

export interface BillingLimitCheck {
  hasViolations: boolean;
  violations: string[];
  overagePolicy: OveragePolicy;
}

