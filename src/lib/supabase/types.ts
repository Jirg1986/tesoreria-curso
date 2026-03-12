// src/lib/supabase/types.ts

export type QuotaType = 'mensual' | 'especial'
export type UserRole  = 'tesorera' | 'apoderado'

export interface School {
  id: string
  name: string
  created_at: string
}

export interface Course {
  id: string
  school_id: string
  name: string
  period: string
  created_at: string
}

export interface AppUser {
  id: string
  auth_id: string
  course_id: string
  username: string
  display_name: string
  role: UserRole
  must_change_password: boolean
  created_at: string
}

export interface Student {
  id: string
  course_id: string
  name: string
  created_at: string
}

export interface ApoderadoStudent {
  apoderado_id: string
  student_id: string
}

export interface Quota {
  id: string
  course_id: string
  name: string
  type: QuotaType
  amount: number
  due_date: string | null
  participant_ids: string[] | null  // null = todo el curso
  created_at: string
}

export interface Payment {
  id: string
  course_id: string
  student_id: string
  quota_id: string
  paid_at: string
  created_by: string | null
  created_at: string
}

export interface Expense {
  id: string
  course_id: string
  description: string
  amount: number
  category: string
  date: string
  created_by: string | null
  created_at: string
}

// â”€â”€ Tipos compuestos para la UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export interface AppUserWithStudents extends AppUser {
  students: Student[]
}

export interface QuotaProjection extends Quota {
  participants: string[]   // IDs de alumnos que deben pagar
  expected: number         // monto total esperado
  paid: number             // monto recaudado
  pct: number              // porcentaje
  missing: number          // monto faltante
}

export interface StudentPaymentStatus {
  student: Student
  quotas: {
    quota: Quota
    applies: boolean
    paid: boolean
    payment?: Payment
  }[]
  totalPaid: number
  totalExpected: number
}

// â”€â”€ Supabase Database types (para el cliente tipado) â”€â”€â”€â”€â”€â”€â”€â”€â”€
export type Database = {
  public: {
    Tables: {
      schools:             { Row: School;           Insert: Omit<School,'id'|'created_at'>;           Update: Partial<School> }
      courses:             { Row: Course;           Insert: Omit<Course,'id'|'created_at'>;           Update: Partial<Course> }
      app_users:           { Row: AppUser;          Insert: Omit<AppUser,'id'|'created_at'>;          Update: Partial<AppUser> }
      students:            { Row: Student;          Insert: Omit<Student,'id'|'created_at'>;          Update: Partial<Student> }
      apoderado_students:  { Row: ApoderadoStudent; Insert: ApoderadoStudent;                         Update: Partial<ApoderadoStudent> }
      quotas:              { Row: Quota;            Insert: Omit<Quota,'id'|'created_at'>;            Update: Partial<Quota> }
      payments:            { Row: Payment;          Insert: Omit<Payment,'id'|'created_at'>;          Update: Partial<Payment> }
      expenses:            { Row: Expense;          Insert: Omit<Expense,'id'|'created_at'>;          Update: Partial<Expense> }
    }
  }
}

