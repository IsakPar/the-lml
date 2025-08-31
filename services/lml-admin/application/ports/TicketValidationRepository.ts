import { Result } from '@thankful/result';
import { RepositoryError } from './VenueAccountRepository.js';
import { TicketInfo, CustomerInfo, ValidationLocation } from '../usecases/ValidateVenueTickets.js';

/**
 * Generic Ticket Validation Repository Port
 * Handles ticket validation operations for any venue
 */
export interface TicketValidationRepository {
  /**
   * Check if ticket has already been validated
   */
  isTicketAlreadyValidated(ticketId: string, venueId: string): Promise<Result<boolean, string>>;

  /**
   * Get ticket information from booking system
   */
  getTicketInfo(ticketId: string, venueId: string): Promise<Result<TicketInfo, string>>;

  /**
   * Get customer information (venue-scoped)
   */
  getCustomerInfo(customerId: string, venueId: string): Promise<Result<CustomerInfo, string>>;

  /**
   * Record validation attempt
   */
  recordValidation(validationData: ValidationAttemptData): Promise<string>;

  /**
   * Mark ticket as validated in booking system
   */
  markTicketValidated(ticketId: string, validationId: string, validatedBy: string): Promise<Result<void, string>>;

  /**
   * Get validation history for venue
   */
  getValidationHistory(venueId: string, options?: ValidationHistoryOptions): Promise<Result<ValidationEvent[], string>>;

  /**
   * Get validation statistics for venue
   */
  getValidationStats(venueId: string, period: StatsPeriod): Promise<Result<ValidationStats, string>>;

  /**
   * Find validation by ID
   */
  findValidationById(validationId: string): Promise<Result<ValidationEvent | null, string>>;
}

/**
 * Data structures for validation operations
 */
export interface ValidationAttemptData {
  venueId: string;
  validatorUserId: string;
  qrCodeData: string;
  result: string;
  success: boolean;
  ticketId?: string;
  bookingId?: string;
  customerId?: string;
  deviceId?: string;
  validationLocation?: ValidationLocation;
  correlationId?: string;
}

export interface ValidationEvent {
  id: string;
  venueId: string;
  ticketId?: string;
  bookingId?: string;
  customerId?: string;
  validatorUserId: string;
  validatorName: string;
  validationStatus: string;
  ticketInfo?: TicketInfo;
  customerInfo?: CustomerInfo;
  deviceId?: string;
  validationLocation?: ValidationLocation;
  attemptedAt: Date;
  processedAt: Date;
  correlationId?: string;
  errorMessage?: string;
}

export interface ValidationHistoryOptions {
  limit?: number;
  offset?: number;
  startDate?: Date;
  endDate?: Date;
  validatorUserId?: string;
  status?: string;
  showId?: string;
}

export interface ValidationStats {
  venueId: string;
  period: StatsPeriod;
  startDate: Date;
  endDate: Date;
  totalValidations: number;
  successfulValidations: number;
  failedValidations: number;
  fraudAttempts: number;
  duplicateAttempts: number;
  uniqueValidators: number;
  averageValidationTimeMs: number;
  validationsByHour: HourlyValidationStats[];
  validationsByShow: ShowValidationStats[];
  topValidators: ValidatorStats[];
}

export interface HourlyValidationStats {
  hour: number;
  date: Date;
  validations: number;
  success: number;
  failed: number;
}

export interface ShowValidationStats {
  showId: string;
  showTitle: string;
  performanceDateTime: Date;
  totalTickets: number;
  validatedTickets: number;
  validationRate: number;
}

export interface ValidatorStats {
  validatorUserId: string;
  validatorName: string;
  totalValidations: number;
  successRate: number;
  averageValidationTimeMs: number;
}

export enum StatsPeriod {
  HOUR = 'hour',
  DAY = 'day',
  WEEK = 'week',
  MONTH = 'month',
  QUARTER = 'quarter',
  YEAR = 'year'
}


