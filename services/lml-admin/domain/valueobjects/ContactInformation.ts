import { Result } from '@thankful/result';

/**
 * Contact Information value object
 * Encapsulates all contact details for a venue
 */
export interface ContactInformationData {
  primaryContact: Contact;
  billingContact?: Contact;
  technicalContact?: Contact;
  emergencyContact?: Contact;
  additionalContacts?: NamedContact[];
}

export interface Contact {
  name: string;
  email: string;
  phone: string;
  title?: string;
  department?: string;
}

export interface NamedContact extends Contact {
  id: string;
  role: string;
}

export class ContactInformation {
  private constructor(
    private readonly _data: ContactInformationData
  ) {}

  public static create(data: ContactInformationData): Result<ContactInformation, string> {
    const validation = ContactInformation.validate(data);
    if (!validation.success) {
      return validation;
    }

    return Result.success(new ContactInformation(data));
  }

  public static createDefault(): ContactInformation {
    const defaultData: ContactInformationData = {
      primaryContact: {
        name: '',
        email: '',
        phone: ''
      }
    };

    return new ContactInformation(defaultData);
  }

  private static validate(data: ContactInformationData): Result<void, string> {
    // Validate primary contact (required)
    if (!data.primaryContact) {
      return Result.failure('Primary contact is required');
    }

    const primaryValidation = this.validateContact(data.primaryContact, 'Primary contact');
    if (!primaryValidation.success) {
      return primaryValidation;
    }

    // Validate billing contact if provided
    if (data.billingContact) {
      const billingValidation = this.validateContact(data.billingContact, 'Billing contact');
      if (!billingValidation.success) {
        return billingValidation;
      }
    }

    // Validate technical contact if provided
    if (data.technicalContact) {
      const technicalValidation = this.validateContact(data.technicalContact, 'Technical contact');
      if (!technicalValidation.success) {
        return technicalValidation;
      }
    }

    // Validate emergency contact if provided
    if (data.emergencyContact) {
      const emergencyValidation = this.validateContact(data.emergencyContact, 'Emergency contact');
      if (!emergencyValidation.success) {
        return emergencyValidation;
      }
    }

    // Validate additional contacts if provided
    if (data.additionalContacts) {
      for (const contact of data.additionalContacts) {
        if (!contact.id || !contact.role) {
          return Result.failure('Additional contacts must have ID and role');
        }

        const contactValidation = this.validateContact(contact, `Additional contact (${contact.role})`);
        if (!contactValidation.success) {
          return contactValidation;
        }
      }

      // Check for duplicate IDs
      const ids = data.additionalContacts.map(c => c.id);
      const uniqueIds = new Set(ids);
      if (ids.length !== uniqueIds.size) {
        return Result.failure('Additional contacts must have unique IDs');
      }
    }

    return Result.success(undefined);
  }

  private static validateContact(contact: Contact, contextName: string): Result<void, string> {
    if (!contact.name || contact.name.trim().length === 0) {
      return Result.failure(`${contextName} name is required`);
    }

    if (contact.name.trim().length > 100) {
      return Result.failure(`${contextName} name must be 100 characters or less`);
    }

    if (!contact.email || !this.isValidEmail(contact.email)) {
      return Result.failure(`${contextName} must have a valid email address`);
    }

    if (!contact.phone || !this.isValidPhone(contact.phone)) {
      return Result.failure(`${contextName} must have a valid phone number`);
    }

    if (contact.title && contact.title.length > 100) {
      return Result.failure(`${contextName} title must be 100 characters or less`);
    }

    if (contact.department && contact.department.length > 100) {
      return Result.failure(`${contextName} department must be 100 characters or less`);
    }

    return Result.success(undefined);
  }

  private static isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  private static isValidPhone(phone: string): boolean {
    // Allow various phone number formats
    return /^[\+]?[\d\s\-\(\)]{10,20}$/.test(phone);
  }

  /**
   * Update primary contact
   */
  public updatePrimaryContact(contact: Contact): Result<ContactInformation, string> {
    const validation = ContactInformation.validateContact(contact, 'Primary contact');
    if (!validation.success) {
      return validation;
    }

    const newData = { ...this._data, primaryContact: contact };
    return ContactInformation.create(newData);
  }

  /**
   * Update billing contact
   */
  public updateBillingContact(contact: Contact | undefined): Result<ContactInformation, string> {
    if (contact) {
      const validation = ContactInformation.validateContact(contact, 'Billing contact');
      if (!validation.success) {
        return validation;
      }
    }

    const newData = { ...this._data, billingContact: contact };
    return ContactInformation.create(newData);
  }

  /**
   * Update technical contact
   */
  public updateTechnicalContact(contact: Contact | undefined): Result<ContactInformation, string> {
    if (contact) {
      const validation = ContactInformation.validateContact(contact, 'Technical contact');
      if (!validation.success) {
        return validation;
      }
    }

    const newData = { ...this._data, technicalContact: contact };
    return ContactInformation.create(newData);
  }

  /**
   * Update emergency contact
   */
  public updateEmergencyContact(contact: Contact | undefined): Result<ContactInformation, string> {
    if (contact) {
      const validation = ContactInformation.validateContact(contact, 'Emergency contact');
      if (!validation.success) {
        return validation;
      }
    }

    const newData = { ...this._data, emergencyContact: contact };
    return ContactInformation.create(newData);
  }

  /**
   * Add additional contact
   */
  public addAdditionalContact(contact: NamedContact): Result<ContactInformation, string> {
    const validation = ContactInformation.validateContact(contact, 'Additional contact');
    if (!validation.success) {
      return validation;
    }

    if (!contact.id || !contact.role) {
      return Result.failure('Additional contact must have ID and role');
    }

    const additionalContacts = this._data.additionalContacts || [];
    
    // Check if ID already exists
    if (additionalContacts.some(c => c.id === contact.id)) {
      return Result.failure('Additional contact with this ID already exists');
    }

    const newAdditionalContacts = [...additionalContacts, contact];
    const newData = { ...this._data, additionalContacts: newAdditionalContacts };
    
    return ContactInformation.create(newData);
  }

  /**
   * Remove additional contact
   */
  public removeAdditionalContact(contactId: string): ContactInformation {
    const additionalContacts = this._data.additionalContacts || [];
    const newAdditionalContacts = additionalContacts.filter(c => c.id !== contactId);
    const newData = { ...this._data, additionalContacts: newAdditionalContacts };
    
    return new ContactInformation(newData);
  }

  /**
   * Get contact by role
   */
  public getContactByRole(role: string): NamedContact | undefined {
    return this._data.additionalContacts?.find(c => c.role === role);
  }

  /**
   * Get all emails for notifications
   */
  public getAllEmails(): string[] {
    const emails: string[] = [this._data.primaryContact.email];

    if (this._data.billingContact) {
      emails.push(this._data.billingContact.email);
    }

    if (this._data.technicalContact) {
      emails.push(this._data.technicalContact.email);
    }

    if (this._data.emergencyContact) {
      emails.push(this._data.emergencyContact.email);
    }

    if (this._data.additionalContacts) {
      emails.push(...this._data.additionalContacts.map(c => c.email));
    }

    // Remove duplicates
    return [...new Set(emails)];
  }

  /**
   * Get primary notification email
   */
  public getPrimaryNotificationEmail(): string {
    return this._data.primaryContact.email;
  }

  /**
   * Get billing notification email
   */
  public getBillingNotificationEmail(): string {
    return this._data.billingContact?.email || this._data.primaryContact.email;
  }

  /**
   * Get technical notification email
   */
  public getTechnicalNotificationEmail(): string {
    return this._data.technicalContact?.email || this._data.primaryContact.email;
  }

  /**
   * Check if contact information is complete
   */
  public isComplete(): boolean {
    return !!(
      this._data.primaryContact.name &&
      this._data.primaryContact.email &&
      this._data.primaryContact.phone
    );
  }

  /**
   * Getters
   */
  public get data(): ContactInformationData {
    return {
      primaryContact: { ...this._data.primaryContact },
      billingContact: this._data.billingContact ? { ...this._data.billingContact } : undefined,
      technicalContact: this._data.technicalContact ? { ...this._data.technicalContact } : undefined,
      emergencyContact: this._data.emergencyContact ? { ...this._data.emergencyContact } : undefined,
      additionalContacts: this._data.additionalContacts ? 
        this._data.additionalContacts.map(c => ({ ...c })) : undefined
    };
  }

  public get primaryContact(): Contact {
    return { ...this._data.primaryContact };
  }

  public get billingContact(): Contact | undefined {
    return this._data.billingContact ? { ...this._data.billingContact } : undefined;
  }

  public get technicalContact(): Contact | undefined {
    return this._data.technicalContact ? { ...this._data.technicalContact } : undefined;
  }

  public get emergencyContact(): Contact | undefined {
    return this._data.emergencyContact ? { ...this._data.emergencyContact } : undefined;
  }

  public get additionalContacts(): NamedContact[] {
    return this._data.additionalContacts ? 
      this._data.additionalContacts.map(c => ({ ...c })) : [];
  }

  /**
   * Serialization
   */
  public toJSON(): ContactInformationData {
    return this.data;
  }
}

