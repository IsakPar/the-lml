import { Result } from '@thankful/shared';
import { PostgresAdapter, BaseRepository } from '@thankful/database';
import { UserRepository, UserSearchCriteria, UserSearchResult, UserRole, RepositoryError } from '../../application/ports/UserRepository.js';
import { User } from '../../domain/entities/User.js';
import { Email } from '../../domain/valueobjects/Email.js';
import { PhoneNumber } from '../../domain/valueobjects/PhoneNumber.js';
import { UserProfile } from '../../domain/valueobjects/UserProfile.js';

/**
 * PostgreSQL implementation of UserRepository
 * Handles all user data persistence operations
 */
export class PostgresUserRepository extends BaseRepository implements UserRepository {
  constructor(db: PostgresAdapter) {
    super(db);
  }

  /**
   * Save a user (create or update)
   */
  async save(user: User): Promise<Result<User, RepositoryError>> {
    try {
      const userData = this.mapUserToRow(user);
      
      // Check if user exists
      const existingUser = await this.db.queryOne<{ id: string }>(
        'SELECT id FROM identity.users WHERE id = $1 AND tenant_id = lml.current_tenant()',
        [user.getId()]
      );

      let savedUserData: any;
      
      if (existingUser) {
        // Update existing user
        savedUserData = await this.db.queryOne(`
          UPDATE identity.users 
          SET email = $2, phone = $3, password_hash = $4, role = $5,
              is_email_verified = $6, is_phone_verified = $7,
              first_name = $8, last_name = $9, date_of_birth = $10,
              avatar_url = $11, preferences = $12, updated_at = NOW()
          WHERE id = $1 AND tenant_id = lml.current_tenant()
          RETURNING *
        `, [
          userData.id, userData.email, userData.phone, userData.password_hash,
          userData.role, userData.is_email_verified, userData.is_phone_verified,
          userData.first_name, userData.last_name, userData.date_of_birth,
          userData.avatar_url, userData.preferences
        ]);
      } else {
        // Insert new user
        savedUserData = await this.db.queryOne(`
          INSERT INTO identity.users (
            id, tenant_id, email, phone, password_hash, role, is_email_verified, is_phone_verified,
            first_name, last_name, date_of_birth, avatar_url, preferences
          ) VALUES ($1, lml.current_tenant(), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
          RETURNING *
        `, [
          userData.id, userData.email, userData.phone, userData.password_hash,
          userData.role, userData.is_email_verified, userData.is_phone_verified,
          userData.first_name, userData.last_name, userData.date_of_birth,
          userData.avatar_url, userData.preferences
        ]);
      }

      const reconstitutedUser = await this.mapRowToUser(savedUserData);
      return Result.success(reconstitutedUser);
      
    } catch (error: any) {
      console.error('Error saving user:', error);
      
      // Handle specific PostgreSQL errors
      if (error.code === '23505') { // Unique violation
        if (error.constraint === 'users_email_unique') {
          return Result.failure(RepositoryError.constraintViolation(
            'Email address is already registered',
            'users_email_unique'
          ));
        }
        if (error.constraint === 'users_phone_unique') {
          return Result.failure(RepositoryError.constraintViolation(
            'Phone number is already registered',
            'users_phone_unique'
          ));
        }
      }

      return Result.failure(RepositoryError.unknown('Failed to save user', { error: error.message }));
    }
  }

  /**
   * Find user by ID
   */
  async findById(id: string): Promise<Result<User | null, RepositoryError>> {
    try {
      const userData = await this.db.queryOne(`
        SELECT * FROM identity.users WHERE id = $1 AND tenant_id = lml.current_tenant()
      `, [id]);

      if (!userData) {
        return Result.success(null);
      }

      const user = await this.mapRowToUser(userData);
      return Result.success(user);
      
    } catch (error: any) {
      console.error('Error finding user by ID:', error);
      return Result.failure(RepositoryError.unknown('Failed to find user', { error: error.message }));
    }
  }

  /**
   * Find user by email
   */
  async findByEmail(email: Email): Promise<Result<User | null, RepositoryError>> {
    try {
      const userData = await this.db.queryOne(`
        SELECT * FROM identity.users WHERE email = $1 AND tenant_id = lml.current_tenant()
      `, [email.value]);

      if (!userData) {
        return Result.success(null);
      }

      const user = await this.mapRowToUser(userData);
      return Result.success(user);
      
    } catch (error: any) {
      console.error('Error finding user by email:', error);
      return Result.failure(RepositoryError.unknown('Failed to find user', { error: error.message }));
    }
  }

  /**
   * Find user by phone number
   */
  async findByPhone(phone: PhoneNumber): Promise<Result<User | null, RepositoryError>> {
    try {
      const userData = await this.db.queryOne(`
        SELECT * FROM identity.users WHERE phone = $1 AND tenant_id = lml.current_tenant()
      `, [phone.value]);

      if (!userData) {
        return Result.success(null);
      }

      const user = await this.mapRowToUser(userData);
      return Result.success(user);
      
    } catch (error: any) {
      console.error('Error finding user by phone:', error);
      return Result.failure(RepositoryError.unknown('Failed to find user', { error: error.message }));
    }
  }

  /**
   * Check if email exists
   */
  async emailExists(email: Email): Promise<Result<boolean, RepositoryError>> {
    try {
      const result = await this.db.queryOne<{ exists: boolean }>(
        'SELECT EXISTS(SELECT 1 FROM identity.users WHERE email = $1 AND tenant_id = lml.current_tenant()) as exists',
        [email.value]
      );
      
      return Result.success(result!.exists);
      
    } catch (error: any) {
      console.error('Error checking email existence:', error);
      return Result.failure(RepositoryError.unknown('Failed to check email', { error: error.message }));
    }
  }

  /**
   * Check if phone exists
   */
  async phoneExists(phone: PhoneNumber): Promise<Result<boolean, RepositoryError>> {
    try {
      const result = await this.db.queryOne<{ exists: boolean }>(
        'SELECT EXISTS(SELECT 1 FROM identity.users WHERE phone = $1 AND tenant_id = lml.current_tenant()) as exists',
        [phone.value]
      );
      
      return Result.success(result!.exists);
      
    } catch (error: any) {
      console.error('Error checking phone existence:', error);
      return Result.failure(RepositoryError.unknown('Failed to check phone', { error: error.message }));
    }
  }

  /**
   * Find users by role
   */
  async findByRole(role: UserRole): Promise<Result<User[], RepositoryError>> {
    try {
      const usersData = await this.db.queryMany(`
        SELECT * FROM identity.users WHERE role = $1 AND tenant_id = lml.current_tenant() ORDER BY created_at DESC
      `, [role]);

      const users = await Promise.all(
        usersData.map(userData => this.mapRowToUser(userData))
      );

      return Result.success(users);
      
    } catch (error: any) {
      console.error('Error finding users by role:', error);
      return Result.failure(RepositoryError.unknown('Failed to find users', { error: error.message }));
    }
  }

  /**
   * Search users with pagination
   */
  async search(criteria: UserSearchCriteria): Promise<Result<UserSearchResult, RepositoryError>> {
    try {
      let baseQuery = 'SELECT * FROM identity.users WHERE 1=1';
      const params: any[] = [];
      let paramIndex = 1;

      // Build WHERE conditions
      if (criteria.email) {
        baseQuery += ` AND email ILIKE $${paramIndex}`;
        params.push(`%${criteria.email}%`);
        paramIndex++;
      }

      if (criteria.role) {
        baseQuery += ` AND role = $${paramIndex}`;
        params.push(criteria.role);
        paramIndex++;
      }

      if (criteria.isEmailVerified !== undefined) {
        baseQuery += ` AND is_email_verified = $${paramIndex}`;
        params.push(criteria.isEmailVerified);
        paramIndex++;
      }

      if (criteria.createdAfter) {
        baseQuery += ` AND created_at >= $${paramIndex}`;
        params.push(criteria.createdAfter);
        paramIndex++;
      }

      if (criteria.createdBefore) {
        baseQuery += ` AND created_at <= $${paramIndex}`;
        params.push(criteria.createdBefore);
        paramIndex++;
      }

      // Add sorting
      const sortBy = criteria.sortBy || 'created_at';
      const sortOrder = criteria.sortOrder || 'desc';
      baseQuery += ` ORDER BY ${sortBy} ${sortOrder}`;

      // Use pagination helper from BaseRepository
      const result = await this.paginate<any>(
        baseQuery,
        params,
        criteria.page || 1,
        criteria.limit || 20
      );

      const users = await Promise.all(
        result.data.map(userData => this.mapRowToUser(userData))
      );

      const searchResult: UserSearchResult = {
        users,
        total: result.total,
        page: result.page,
        pages: result.pages,
        hasNext: result.page < result.pages,
        hasPrev: result.page > 1,
      };

      return Result.success(searchResult);
      
    } catch (error: any) {
      console.error('Error searching users:', error);
      return Result.failure(RepositoryError.unknown('Failed to search users', { error: error.message }));
    }
  }

  /**
   * Delete user (soft delete)
   */
  async delete(id: string): Promise<Result<void, RepositoryError>> {
    try {
      await this.softDelete('identity.users', id);
      return Result.success(undefined);
      
    } catch (error: any) {
      console.error('Error deleting user:', error);
      return Result.failure(RepositoryError.unknown('Failed to delete user', { error: error.message }));
    }
  }

  /**
   * Update last login time
   */
  async updateLastLogin(id: string): Promise<Result<void, RepositoryError>> {
    try {
      await this.db.query(
        'UPDATE identity.users SET last_login_at = NOW() WHERE id = $1 AND tenant_id = lml.current_tenant()',
        [id]
      );
      
      return Result.success(undefined);
      
    } catch (error: any) {
      console.error('Error updating last login:', error);
      return Result.failure(RepositoryError.unknown('Failed to update last login', { error: error.message }));
    }
  }

  // ============================================================================
  // PRIVATE MAPPING METHODS
  // ============================================================================

  /**
   * Map User domain object to database row
   */
  private mapUserToRow(user: User): any {
    const profile = user.getProfile();
    
    return {
      id: user.getId(),
      email: user.getEmail().value,
      phone: user.getPhone()?.value || null,
      password_hash: user.getPasswordHash(),
      role: user.getRole(),
      is_email_verified: user.isEmailVerified,
      is_phone_verified: user.isPhoneVerified,
      first_name: profile.value.firstName,
      last_name: profile.value.lastName,
      date_of_birth: profile.value.dateOfBirth || null,
      avatar_url: profile.value.avatarUrl || null,
      preferences: JSON.stringify(profile.value.preferences),
    };
  }

  /**
   * Map database row to User domain object
   */
  private async mapRowToUser(row: any): Promise<User> {
    // Create Email value object
    const emailResult = Email.create(row.email);
    if (emailResult.isFailure) {
      throw new Error(`Invalid email in database: ${row.email}`);
    }

    // Create PhoneNumber value object if present
    let phone: PhoneNumber | undefined;
    if (row.phone) {
      const phoneResult = PhoneNumber.create(row.phone);
      if (phoneResult.isFailure) {
        throw new Error(`Invalid phone in database: ${row.phone}`);
      }
      phone = phoneResult.value;
    }

    // Create UserProfile value object
    const profileResult = UserProfile.create({
      firstName: row.first_name,
      lastName: row.last_name,
      dateOfBirth: row.date_of_birth,
      avatarUrl: row.avatar_url,
      preferences: typeof row.preferences === 'string' 
        ? JSON.parse(row.preferences) 
        : row.preferences,
    });
    
    if (profileResult.isFailure) {
      throw new Error(`Invalid profile data in database for user ${row.id}`);
    }

    // For now, we'll use a simplified User constructor
    // In a full implementation, we'd need to properly reconstruct the aggregate
    const user = Object.create(User.prototype);
    user.id = row.id;
    user._email = emailResult.value;
    user._phone = phone;
    user._profile = profileResult.value;
    user._role = row.role;
    user._passwordHash = row.password_hash;
    user._isEmailVerified = row.is_email_verified;
    user._isPhoneVerified = row.is_phone_verified;
    user.createdAt = row.created_at;
    user._lastLoginAt = row.last_login_at;

    return user;
  }
}
