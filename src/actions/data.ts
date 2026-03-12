'use server'
// src/actions/data.ts
// Todas las operaciones CRUD â€” protegidas por RLS en Supabase

import { revalidatePath } from 'next/cache'
import { createClient } from '` @/lib/supabase/server'
import { getCurrentAppUser } from './auth'
import type { QuotaType } from '` @/lib/supabase/types'

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ALUMNOS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getStudentsAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('students')
    .select('*')
    .order('name')
  if (error) throw error
  return data ?? []
}

export async function createStudentAction(name: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('students')
    .insert({ course_id: user.course_id, name })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteStudentAction(studentId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('students').delete().eq('id', studentId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// CUOTAS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getQuotasAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('quotas')
    .select('*')
    .order('created_at')
  if (error) throw error
  return data ?? []
}

export async function createQuotaAction(params: {
  name: string
  type: QuotaType
  amount: number
  due_date?: string
  participant_ids: string[] | null
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('quotas').insert({
    course_id:       user.course_id,
    name:            params.name,
    type:            params.type,
    amount:          params.amount,
    due_date:        params.due_date || null,
    participant_ids: params.participant_ids,
  })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteQuotaAction(quotaId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('quotas').delete().eq('id', quotaId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGOS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getPaymentsAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function createPaymentAction(params: {
  student_id: string
  quota_id:   string
  paid_at:    string
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('payments').insert({
    course_id:  user.course_id,
    student_id: params.student_id,
    quota_id:   params.quota_id,
    paid_at:    params.paid_at,
    created_by: user.id,
  })

  // El unique constraint en (student_id, quota_id) evita duplicados
  if (error) {
    if (error.code === '23505') return { error: 'Este alumno ya tiene registrado este pago.' }
    return { error: error.message }
  }

  revalidatePath('/dashboard')
  return { success: true }
}

export async function deletePaymentAction(paymentId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('payments').delete().eq('id', paymentId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GASTOS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getExpensesAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('expenses')
    .select('*')
    .order('date', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function createExpenseAction(params: {
  description: string
  amount:      number
  category:    string
  date:        string
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('expenses').insert({
    course_id:   user.course_id,
    description: params.description,
    amount:      params.amount,
    category:    params.category,
    date:        params.date,
    created_by:  user.id,
  })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteExpenseAction(expenseId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('expenses').delete().eq('id', expenseId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// APODERADOS (lectura)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getApoderadosAction() {
  const supabase = await createClient()
  const { data: users, error } = await supabase
    .from('app_users')
    .select('*')
    .eq('role', 'apoderado')
    .order('display_name')

  if (error) throw error

  // Obtener alumnos de cada apoderado
  const { data: relations } = await supabase
    .from('apoderado_students')
    .select('apoderado_id, student_id, students(id, name)')

  return (users ?? []).map(u => ({
    ...u,
    students: (relations ?? [])
      .filter(r => r.apoderado_id === u.id)
      .map(r => (r as any).students)
      .filter(Boolean),
  }))
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// DATOS DEL APODERADO ACTUAL
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getApoderadoDataAction() {
  const supabase = await createClient()
  const user = await getCurrentAppUser()
  if (!user) return null

  // Alumnos del apoderado
  const { data: relations } = await supabase
    .from('apoderado_students')
    .select('student_id, students(id, name, course_id)')
    .eq('apoderado_id', user.id)

  const students = (relations ?? []).map(r => (r as any).students).filter(Boolean)

  // Todos los datos del curso
  const [quotas, payments, expenses] = await Promise.all([
    getQuotasAction(),
    getPaymentsAction(),
    getExpensesAction(),
  ])

  return { user, students, quotas, payments, expenses }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TODOS LOS DATOS DEL DASHBOARD (tesorera)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getDashboardDataAction() {
  const [students, quotas, payments, expenses, apoderados] = await Promise.all([
    getStudentsAction(),
    getQuotasAction(),
    getPaymentsAction(),
    getExpensesAction(),
    getApoderadosAction(),
  ])
  return { students, quotas, payments, expenses, apoderados }
}

