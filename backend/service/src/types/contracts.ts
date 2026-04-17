export type UserRole =
  | 'ADMIN'
  | 'MANAGER'
  | 'CASHIER'
  | 'TECHNICIAN'
  | 'SUPPORT';

export type MachineStatus =
  | 'AVAILABLE'
  | 'MAINTENANCE'
  | 'IN_USE'
  | 'READY_FOR_PICKUP';

export type OrderStatus =
  | 'BOOKED'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'CANCELLED';

export type PaymentStatus = 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED';
export type PaymentSessionStatus =
  | 'AWAITING_SCAN'
  | 'PROCESSING'
  | 'PAID'
  | 'FAILED';
export type ReservationStatus = 'BOOKED' | 'FULFILLED' | 'CANCELLED';
export type ActiveOrderSessionStage = 'DRAFT' | 'BOOKED' | 'PAID';

export interface PosUserDto {
  id: number;
  username: string;
  displayName: string;
  pin?: string;
  role: UserRole;
}

export interface AuthSessionDto {
  accessToken: string;
  refreshToken?: string | null;
  expiresAt?: string | null;
  user: PosUserDto;
}
