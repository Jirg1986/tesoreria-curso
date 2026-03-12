'use client'
// src/components/ApoderadoDashboard.tsx

import { useTransition } from 'react'
import { logoutAction } from '@/actions/auth'
import type { AppUser, Student, Quota, Payment, Expense } from '@/lib/supabase/types'

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
}

export function ApoderadoDashboard({ data }: { data: ApoderadoData }) {
  const { user, students, quotas, payments, expenses } = data
  const [, startTransition] = useTransition()

  const totalIncome   = payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0)
  const totalExpense  = expenses.reduce((s, e) => s + e.amount, 0)
  const balance       = totalIncome - totalExpense
  const totalExpected = quotas.reduce((s, q) => s + q.amount * quotaParticipants(q, students).length, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0

  const hasPaid = (sid: string, qid: string) => payments.some(p => p.student_id === sid && p.quota_id === qid)

  return (
    <div>
      {/* TOPBAR */}
      <div className="topbar">
        <div>
          <div className="topbar-title">📋 Tesorería <span>Curso</span></div>
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

      <div className="content" style={{ maxWidth: 740 }}>

        {/* Balance general */}
        <div className="card mb-4">
          <div className="card-title">Balance general del curso</div>
          <div className="card-grid card-grid-3 mb-4">
            <div className="kpi kpi-indigo">
              <div className="kpi-label">Saldo actual</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(balance)}</div>
            </div>
            <div className="kpi kpi-green">
              <div className="kpi-label">Recaudado</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(totalIncome)}</div>
            </div>
            <div className="kpi kpi-red">
              <div className="kpi-label">Gastado</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(totalExpense)}</div>
            </div>
          </div>
          <div className="row mb-3">
            <span className="fs-12 c-muted fw-700" style={{ textTransform: 'uppercase', letterSpacing: '0.06em' }}>
              Avance de recaudación del curso
            </span>
            <span className="fw-700 c-indigo fs-13">{globalPct}%</span>
          </div>
          <div className="progress-bar" style={{ height: 9 }}>
            <div className="progress-fill" style={{
              width: `${globalPct}%`,
              background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)'
            }} />
          </div>
          <div className="row mt-3">
            <span className="fs-11 c-muted">Esperado: {clp(totalExpected)}</span>
            <span className="fs-11 c-muted">Por cobrar: <strong style={{ color: 'var(--red)' }}>{clp(totalExpected - totalIncome)}</strong></span>
          </div>
        </div>

        {/* Estado por cada hijo del apoderado */}
        {data.students.map(s => {
          const myPays     = payments.filter(p => p.student_id === s.id)
          const myQuotas   = quotas.filter(q => isParticipant(q, s.id, students))
          const myExpected = myQuotas.reduce((sum, q) => sum + q.amount, 0)
          const myPaid     = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
          const allPaid    = myQuotas.every(q => hasPaid(s.id, q.id))

          return (
            <div key={s.id} className="card mb-4">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
                <div className="card-title" style={{ marginBottom: 0 }}>📚 {s.name}</div>
                {allPaid && myQuotas.length > 0
                  ? <span className="badge badge-green">✓ Al día</span>
                  : <span className="badge badge-amber">{myQuotas.filter(q => !hasPaid(s.id, q.id)).length} pendiente(s)</span>
                }
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
                {quotas.map(q => {
                  const applies = isParticipant(q, s.id, students)
                  const paid    = hasPaid(s.id, q.id)
                  const pay     = myPays.find(p => p.quota_id === q.id)

                  if (!applies) return (
                    <div key={q.id} style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      background: 'var(--gray-lt)', borderRadius: 9, padding: '11px 14px',
                      border: '1px solid var(--border)', opacity: 0.55
                    }}>
                      <span className="fw-700 fs-13" style={{ color: 'var(--muted)' }}>{q.name}</span>
                      <span className="badge badge-gray">No aplica</span>
                    </div>
                  )

                  return (
                    <div key={q.id} style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      background: paid ? 'var(--green-lt)' : 'var(--red-lt)',
                      borderRadius: 9, padding: '11px 14px',
                      border: `1px solid ${paid ? '#bbf7d0' : '#fecaca'}`
                    }}>
                      <div>
                        <div style={{ display: 'flex', gap: 7, alignItems: 'center', marginBottom: 3 }}>
                          <span className="fw-700 fs-13">{q.name}</span>
                          <span className={`badge ${q.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>
                            {q.type === 'mensual' ? 'Mensual' : 'Especial'}
                          </span>
                        </div>
                        {paid && <div className="fs-12 c-muted">Pagado el {dateF(pay?.paid_at)}</div>}
                        {!paid && q.due_date && <div className="fs-12" style={{ color: 'var(--red)' }}>Vence: {dateF(q.due_date)}</div>}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span className="fw-700 fs-13" style={{ color: paid ? 'var(--green)' : 'var(--red)' }}>{clp(q.amount)}</span>
                        <span className={`badge ${paid ? 'badge-green' : 'badge-red'}`}>{paid ? '✓ Pagado' : 'Pendiente'}</span>
                      </div>
                    </div>
                  )
                })}
              </div>

              <div style={{ background: 'var(--bg)', borderRadius: 9, padding: '12px 14px' }}>
                <div className="row mb-3">
                  <span className="fs-13 c-muted">Total pagado</span>
                  <span className="fw-700 c-green" style={{ fontFamily: "'Fraunces',serif", fontSize: 16 }}>{clp(myPaid)}</span>
                </div>
                <div className="row">
                  <span className="fs-13 c-muted">Pendiente (cuotas que te aplican)</span>
                  <span className="fw-700" style={{ fontFamily: "'Fraunces',serif", fontSize: 16, color: myExpected - myPaid > 0 ? 'var(--red)' : 'var(--green)' }}>
                    {clp(myExpected - myPaid)}
                  </span>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

