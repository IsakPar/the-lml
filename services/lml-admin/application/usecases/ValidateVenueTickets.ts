import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { VenueStaffRepository } from '../ports/VenueStaffRepository.js';
import { TicketValidationRepository } from '../ports/TicketValidationRepository.js';
import { DomainEventPublisher } from '@thankful/events';

/**
 * Generic venue ticket validation use case
 * Works for any venue's tickets with complete venue isolation
 */
export interface ValidateVenueTicketsRequest {
  venueId: string;
  validatorUserId: string;
  qrCodeData: string;
  deviceId?: string;
  validationLocation?: ValidationLocation;
  correlationId?: string;
}

export interface ValidationLocation {
  latitude?: number;
  longitude?: number;
  venue_zone?: string;
  entrance?: string;
}

export interface ValidateVenueTicketsResponse {
  validationId: string;
  isValid: boolean;
  validationStatus: ValidationStatus;
  ticketInfo?: TicketInfo;
  customerInfo?: CustomerInfo;
  errorMessage?: string;
  warnings?: string[];
}

export interface TicketInfo {
  ticketId: string;
  bookingId: string;
  showTitle: string;
  performanceDateTime: Date;
  seatInfo: {
    section: string;
    row: string;
    number: string;
  };
  priceInfo: {
    priceTier: string;
    paidAmount: number;
    currency: string;
  };
}

export interface CustomerInfo {
  customerId: string;
  customerName: string;
  customerEmail: string;
  isVip: boolean;
  totalVisits: number;
  lastVisit?: Date;
}

export enum ValidationStatus {
  VALID = 'valid',
  INVALID_SIGNATURE = 'invalid_signature',
  EXPIRED = 'expired',
  ALREADY_USED = 'already_used',
  WRONG_VENUE = 'wrong_venue',
  WRONG_SHOW = 'wrong_show',
  WRONG_TIME = 'wrong_time',
  INVALID_FORMAT = 'invalid_format',
  FRAUD_DETECTED = 'fraud_detected',
  SYSTEM_ERROR = 'system_error'
}

export class ValidateVenueTickets {
  private readonly logger: Logger;

  constructor(
    private readonly venueStaffRepository: VenueStaffRepository,
    private readonly ticketValidationRepository: TicketValidationRepository,
    private readonly eventPublisher: DomainEventPublisher,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'validate-venue-tickets' });
  }

  async execute(
    request: ValidateVenueTicketsRequest
  ): Promise<Result<ValidateVenueTicketsResponse, string>> {
    try {
      this.logger.info('Validating venue ticket', {
        venueId: request.venueId,
        validatorUserId: request.validatorUserId,
        deviceId: request.deviceId,
        correlationId: request.correlationId
      });

      // Validate request
      const requestValidation = this.validateRequest(request);
      if (!requestValidation.success) {
        return requestValidation;
      }

      // Verify validator has permission for this venue
      const validatorCheck = await this.verifyValidatorPermissions(
        request.validatorUserId, 
        request.venueId
      );
      if (!validatorCheck.success) {
        return Result.failure(`Validator permission denied: ${validatorCheck.error}`);
      }

      // Parse and validate QR code
      const qrValidation = await this.validateQRCode(request.qrCodeData, request.venueId);
      if (!qrValidation.success) {
        // Record failed validation
        await this.recordValidationAttempt(request, qrValidation.error, false);
        
        return Result.success({
          validationId: this.generateValidationId(),
          isValid: false,
          validationStatus: this.mapErrorToValidationStatus(qrValidation.error),
          errorMessage: qrValidation.error
        });
      }

      const ticketData = qrValidation.value;

      // Check if ticket was already validated
      const duplicateCheck = await this.checkForDuplicateValidation(ticketData.ticketId, request.venueId);
      if (duplicateCheck.success && duplicateCheck.value) {
        await this.recordValidationAttempt(request, 'Ticket already validated', false);
        
        return Result.success({
          validationId: this.generateValidationId(),
          isValid: false,
          validationStatus: ValidationStatus.ALREADY_USED,
          errorMessage: 'Ticket has already been validated'
        });
      }

      // Get ticket and customer information
      const ticketInfoResult = await this.getTicketInformation(ticketData.ticketId, request.venueId);
      const customerInfoResult = await this.getCustomerInformation(ticketData.customerId, request.venueId);

      // Record successful validation
      const validationId = await this.recordValidationAttempt(request, 'Valid ticket', true, {
        ticketId: ticketData.ticketId,
        bookingId: ticketData.bookingId,
        customerId: ticketData.customerId
      });

      // Mark ticket as validated in booking system
      await this.markTicketAsValidated(ticketData.ticketId, validationId, request.validatorUserId);

      this.logger.info('Ticket validated successfully', {
        validationId,
        ticketId: ticketData.ticketId,
        venueId: request.venueId,
        correlationId: request.correlationId
      });

      return Result.success({
        validationId,
        isValid: true,
        validationStatus: ValidationStatus.VALID,
        ticketInfo: ticketInfoResult.success ? ticketInfoResult.value : undefined,
        customerInfo: customerInfoResult.success ? customerInfoResult.value : undefined
      });

    } catch (error) {
      this.logger.error('Unexpected error validating venue ticket', {
        error: error instanceof Error ? error.message : String(error),
        request,
        correlationId: request.correlationId
      });

      return Result.failure(`Unexpected error validating ticket: ${
        error instanceof Error ? error.message : String(error)
      }`);
    }
  }

  private validateRequest(request: ValidateVenueTicketsRequest): Result<void, string> {
    if (!request.venueId?.trim()) {
      return Result.failure('Venue ID is required');
    }

    if (!request.validatorUserId?.trim()) {
      return Result.failure('Validator user ID is required');
    }

    if (!request.qrCodeData?.trim()) {
      return Result.failure('QR code data is required');
    }

    return Result.success(undefined);
  }

  private async verifyValidatorPermissions(
    validatorUserId: string, 
    venueId: string
  ): Promise<Result<void, string>> {
    const staffResult = await this.venueStaffRepository.findByUserAndVenue(validatorUserId, venueId);
    
    if (!staffResult.success || !staffResult.value) {
      return Result.failure('User is not staff member for this venue');
    }

    const staff = staffResult.value;
    
    if (staff.status !== 'active') {
      return Result.failure('Staff member is not active');
    }

    if (!staff.permissions.tickets.validate) {
      return Result.failure('Staff member does not have ticket validation permission');
    }

    return Result.success(undefined);
  }

  private async validateQRCode(qrCodeData: string, venueId: string): Promise<Result<QRCodeTicketData, string>> {
    try {
      // Parse QR code (assuming JSON format)
      const qrData = JSON.parse(qrCodeData);

      // Verify required fields
      if (!qrData.ticketId || !qrData.venueId || !qrData.bookingId) {
        return Result.failure('Invalid QR code format - missing required fields');
      }

      // Verify venue ID matches
      if (qrData.venueId !== venueId) {
        return Result.failure('QR code belongs to different venue');
      }

      // Verify signature if present (add signature validation logic here)
      if (qrData.signature) {
        const signatureValid = await this.verifyQRCodeSignature(qrData);
        if (!signatureValid) {
          return Result.failure('Invalid QR code signature');
        }
      }

      return Result.success({
        ticketId: qrData.ticketId,
        venueId: qrData.venueId,
        bookingId: qrData.bookingId,
        customerId: qrData.customerId,
        showId: qrData.showId,
        performanceId: qrData.performanceId,
        seatId: qrData.seatId,
        issuedAt: new Date(qrData.issuedAt),
        expiresAt: qrData.expiresAt ? new Date(qrData.expiresAt) : undefined
      });

    } catch (error) {
      return Result.failure('Invalid QR code format - not valid JSON');
    }
  }

  private async verifyQRCodeSignature(qrData: any): Promise<boolean> {
    // TODO: Implement signature verification using venue-specific signing keys
    // This would verify the QR code was issued by the proper authority
    return true; // Placeholder
  }

  private async checkForDuplicateValidation(
    ticketId: string, 
    venueId: string
  ): Promise<Result<boolean, string>> {
    return this.ticketValidationRepository.isTicketAlreadyValidated(ticketId, venueId);
  }

  private async getTicketInformation(
    ticketId: string, 
    venueId: string
  ): Promise<Result<TicketInfo, string>> {
    return this.ticketValidationRepository.getTicketInfo(ticketId, venueId);
  }

  private async getCustomerInformation(
    customerId: string, 
    venueId: string
  ): Promise<Result<CustomerInfo, string>> {
    return this.ticketValidationRepository.getCustomerInfo(customerId, venueId);
  }

  private async recordValidationAttempt(
    request: ValidateVenueTicketsRequest,
    result: string,
    success: boolean,
    ticketData?: Partial<QRCodeTicketData>
  ): Promise<string> {
    return this.ticketValidationRepository.recordValidation({
      venueId: request.venueId,
      validatorUserId: request.validatorUserId,
      qrCodeData: request.qrCodeData,
      result,
      success,
      ticketId: ticketData?.ticketId,
      bookingId: ticketData?.bookingId,
      customerId: ticketData?.customerId,
      deviceId: request.deviceId,
      validationLocation: request.validationLocation,
      correlationId: request.correlationId
    });
  }

  private async markTicketAsValidated(
    ticketId: string, 
    validationId: string, 
    validatedBy: string
  ): Promise<void> {
    await this.ticketValidationRepository.markTicketValidated(ticketId, validationId, validatedBy);
  }

  private mapErrorToValidationStatus(error: string): ValidationStatus {
    if (error.includes('different venue')) return ValidationStatus.WRONG_VENUE;
    if (error.includes('signature')) return ValidationStatus.INVALID_SIGNATURE;
    if (error.includes('expired')) return ValidationStatus.EXPIRED;
    if (error.includes('format')) return ValidationStatus.INVALID_FORMAT;
    if (error.includes('already validated')) return ValidationStatus.ALREADY_USED;
    return ValidationStatus.SYSTEM_ERROR;
  }

  private generateValidationId(): string {
    return `val_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

/**
 * Supporting interfaces
 */
export interface QRCodeTicketData {
  ticketId: string;
  venueId: string;
  bookingId: string;
  customerId: string;
  showId: string;
  performanceId: string;
  seatId?: string;
  issuedAt: Date;
  expiresAt?: Date;
}


