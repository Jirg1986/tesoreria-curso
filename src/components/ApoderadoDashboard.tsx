'use client'
// src/components/ApoderadoDashboard.tsx

import { useTransition } from 'react'
import { logoutAction } from '@/actions/auth'
import type { AppUser, Student, Quota, Payment, Expense, Course, School } from '@/lib/supabase/types'

const clp   = (n: number) => `$${Math.round(n).toLocaleString('es-CL')}`
const dateF = (s?: string | null) => s
  ? new Date(s + 'T00:00:00').toLocaleDateString('es-CL', { day: '2-digit', month: 'short', year: 'numeric' })
  : '—'

const quotaParticipants = (q: Quota, students: Student[]) =>
  q.participant_ids ?? students.map(s => s.id)

const isParticipant = (q: Quota, sid: string, students: Student[]) =>
  quotaParticipants(q, students).includes(sid)

interface ApoderadoData {
  user:     AppUser
  students: Student[]
  quotas:   Quota[]
  payments: Payment[]
  expenses: Expense[]
  course:   Course | null
  school:   School | null
}

export function ApoderadoDashboard({ data }: { data: ApoderadoData }) {
  const { user, students, quotas, payments, expenses, course, school } = data
  const [, startTransition] = useTransition()

  // Balance del curso (solo montos, sin "Esperado Total")
  const totalIncome  = payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0)
  const totalExpense = expenses.filter(e => !expenses.some(c => (c.parent_expense_id ?? null) === e.id)).reduce((s, e) => s + e.amount, 0)
  const balance      = totalIncome - totalExpense

  const hasPaid = (sid: string, qid: string) => payments.some(p => p.student_id === sid && p.quota_id === qid)

  const mensualQuotas  = quotas.filter(q => q.type === 'mensual')
  const especialQuotas = quotas.filter(q => q.type === 'especial')

  return (
    <div>
      {/* TOPBAR */}
      <div className="topbar">
        <div className="topbar-brand">
          <div className="topbar-title">📋 {school?.name ?? 'Tesorería'} <span>{course?.name ?? 'Curso'}</span></div>
          <div className="topbar-sub">Vista Apoderado · {user.display_name}</div>
        </div>
        <div className="topbar-right">
          <span className="topbar-user">👤 {user.display_name}</span>
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => startTransition(() => logoutAction())}
          >
            Salir
          </button>
        </div>
      </div>

      <div className="content content-apoderado">

        {/* Info del curso */}
        {(school || course) && (
          <div className="course-info-banner">
            <span className="course-info-school">🏫 {school?.name}</span>
            {course && <span className="course-info-course">📚 {course.name} · {course.period}</span>}
          </div>
        )}

        {/* Balance general (sin Esperado Total) */}
        <div className="card mb-4">
          <div className="card-title">Balance general del curso</div>
          <div className="card-grid card-grid-3 mb-4">
            <div className="kpi kpi-indigo">
              <div className="kpi-label">Saldo actual</div>
              <div className="kpi-value kpi-value-sm">{clp(balance)}</div>
            </div>
            <div className="kpi kpi-green">
              <div className="kpi-label">Recaudado</div>
              <div className="kpi-value kpi-value-sm">{clp(totalIncome)}</div>
            </div>
            <div className="kpi kpi-red">
              <div className="kpi-label">Gastado</div>
              <div className="kpi-value kpi-value-sm">{clp(totalExpense)}</div>
            </div>
          </div>
        </div>

        {/* Sin alumnos asignados */}
        {students.length === 0 && (
          <div className="card" style={{ textAlign: 'center', padding: '32px 20px', color: 'var(--muted)' }}>
            <div style={{ fontSize: 32, marginBottom: 8 }}>👦</div>
            <div style={{ fontSize: 14, fontWeight: 600 }}>No tienes alumnos asignados</div>
            <div style={{ fontSize: 12, marginTop: 4 }}>Contacta a la tesorera del curso.</div>
          </div>
        )}

        {/* Estado por cada alumno */}
        {students.map(s => {
          const myPays     = payments.filter(p => p.student_id === s.id)
          const myQuotas   = quotas.filter(q => isParticipant(q, s.id, students))
          const myExpected = myQuotas.reduce((sum, q) => sum + q.amount, 0)
          const myPaid     = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
          const allPaid    = myQuotas.length > 0 && myQuotas.every(q => hasPaid(s.id, q.id))

          const myMensual  = mensualQuotas.filter(q => isParticipant(q, s.id, students))
          const myEspecial = especialQuotas.filter(q => isParticipant(q, s.id, students))

          return (
            <div key={s.id} className="card mb-4">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
                <div className="card-title" style={{ marginBottom: 0 }}>📚 {s.name}</div>
                {myQuotas.length === 0
                  ? <span className="badge badge-gray">Sin cuotas asignadas</span>
                  : allPaid
                  ? <span className="badge badge-green">✓ Al día</span>
                  : <span className="badge badge-amber">{myQuotas.filter(q => !hasPaid(s.id, q.id)).length} pendiente(s)</span>
                }
              </div>

              {/* Cuotas Mensuales */}
              {myMensual.length > 0 && (
                <div style={{ marginBottom: 16 }}>
                  <div className="quota-section-label">📅 Cuotas Mensuales</div>
                  <div className="quota-list">
                    {myMensual.map(q => <QuotaRow key={q.id} q={q} s={s} myPays={myPays} hasPaid={hasPaid} />)}
                  </div>
                </div>
              )}

              {/* Cuotas Especiales */}
              {myEspecial.length > 0 && (
                <div style={{ marginBottom: 16 }}>
                  <div className="quota-section-label">⭐ Cuotas Especiales</div>
                  <div className="quota-list">
                    {myEspecial.map(q => <QuotaRow key={q.id} q={q} s={s} myPays={myPays} hasPaid={hasPaid} />)}
                  </div>
                </div>
              )}

              {myQuotas.length === 0 && (
                <div style={{ textAlign: 'center', color: 'var(--muted)', fontSize: 13, padding: '12px 0' }}>
                  No hay cuotas registradas aún.
                </div>
              )}

              {/* Resumen del alumno */}
              {myQuotas.length > 0 && (
                <div style={{ background: 'var(--bg)', borderRadius: 9, padding: '12px 14px' }}>
                  <div className="row mb-3">
                    <span className="fs-13 c-muted">Total pagado</span>
                    <span className="fw-700 c-green" style={{ fontFamily: "'Fraunces',serif", fontSize: 16 }}>{clp(myPaid)}</span>
                  </div>
                  <div className="row">
                    <span className="fs-13 c-muted">Pendiente</span>
                    <span className="fw-700" style={{ fontFamily: "'Fraunces',serif", fontSize: 16, color: myExpected - myPaid > 0 ? 'var(--red)' : 'var(--green)' }}>
                      {clp(myExpected - myPaid)}
                    </span>
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function QuotaRow({ q, s, myPays, hasPaid }: {
  q: Quota
  s: Student
  myPays: Payment[]
  hasPaid: (sid: string, qid: string) => boolean
}) {
  const paid = hasPaid(s.id, q.id)
  const pay  = myPays.find(p => p.quota_id === q.id)

  return (
    <div className={`quota-row ${paid ? 'quota-paid' : 'quota-pending'}`}>
      <div>
        <div className="quota-name">{q.name}</div>
        {paid && <div className="fs-12 c-muted">Pagado el {dateF(pay?.paid_at)}</div>}
        {!paid && q.due_date && (
          <div className="fs-12" style={{ color: 'var(--red)' }}>Vence: {dateF(q.due_date)}</div>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span className="fw-700 fs-13" style={{ color: paid ? 'var(--green)' : 'var(--red)' }}>
          {`$${Math.round(q.amount).toLocaleString('es-CL')}`}
        </span>
        <span className={`badge ${paid ? 'badge-green' : 'badge-red'}`}>
          {paid ? '✓ Pagado' : 'Pendiente'}
        </span>
      </div>
    </div>
  )
}
