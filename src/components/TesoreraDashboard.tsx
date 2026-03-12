'use client'
// src/components/TesoreraDashboard.tsx

import { useState, useMemo, useTransition, useCallback } from 'react'
import {
  createQuotaAction, deleteQuotaAction,
  createPaymentAction, deletePaymentAction,
  createExpenseAction, deleteExpenseAction,
  createStudentAction, deleteStudentAction,
} from '@/actions/data'
import {
  createApoderadoAction,
  deleteApoderadoAction,
  resetApoderadoPasswordAction,
  logoutAction,
} from '@/actions/auth'
import type {
  AppUser, Student, Quota, Payment, Expense,
  AppUserWithStudents, QuotaType,
} from '@/lib/supabase/types'

// ─── HELPERS ──────────────────────────────────────────────────
const clp   = (n: number) => `$${Math.round(n).toLocaleString('es-CL')}`
const dateF = (s?: string | null) => s
  ? new Date(s + 'T00:00:00').toLocaleDateString('es-CL', { day: '2-digit', month: 'short', year: 'numeric' })
  : '—'
const nowDate = () => new Date().toISOString().split('T')[0]

const quotaParticipants = (q: Quota, students: Student[]) =>
  q.participant_ids ?? students.map(s => s.id)

const isParticipant = (q: Quota, sid: string, students: Student[]) =>
  quotaParticipants(q, students).includes(sid)

// ─── TIPOS PROPS ──────────────────────────────────────────────
interface Props {
  user:               AppUser
  initialStudents:    Student[]
  initialQuotas:      Quota[]
  initialPayments:    Payment[]
  initialExpenses:    Expense[]
  initialApoderados:  AppUserWithStudents[]
}

// ─── PDF ──────────────────────────────────────────────────────
function generatePDF(
  students: Student[], quotas: Quota[],
  payments: Payment[], expenses: Expense[]
) {
  const totalIncome  = payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0)
  const totalExpense = expenses.reduce((s, e) => s + e.amount, 0)
  const balance      = totalIncome - totalExpense
  const totalExpected = quotas.reduce((s, q) => s + q.amount * quotaParticipants(q, students).length, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0
  const today         = new Date().toLocaleDateString('es-CL', { day: '2-digit', month: 'long', year: 'numeric' })
  const hasPaid       = (sid: string, qid: string) => payments.some(p => p.student_id === sid && p.quota_id === qid)

  const qHeaders = quotas.map(q => `
    <th style="text-align:center;padding:8px 6px;font-size:10px;text-transform:uppercase;letter-spacing:0.05em;color:#8886a0;">
      ${q.name}<br/><span style="font-size:9px;font-weight:400;color:#aaa;">
      ${q.participant_ids === null ? 'Todos' : `${q.participant_ids.length} alumnos`}</span>
    </th>`).join('')

  const rows = students.map(s => {
    const cells = quotas.map(q => {
      const applies = isParticipant(q, s.id, students)
      if (!applies) return `<td style="text-align:center;color:#aaa;font-size:11px;">—</td>`
      const paid = hasPaid(s.id, q.id)
      return `<td style="text-align:center;"><span style="display:inline-block;padding:2px 8px;border-radius:99px;font-size:10px;font-weight:700;background:${paid ? '#d1fae5' : '#fee2e2'};color:${paid ? '#065f46' : '#991b1b'};">${paid ? '✓ Pagado' : 'Pendiente'}</span></td>`
    }).join('')
    const myTotal = payments.filter(p => p.student_id === s.id)
      .reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
    return `<tr><td style="font-weight:600;padding:8px 10px;">${s.name}</td>${cells}<td style="text-align:center;font-weight:700;color:#5b4df5;">${clp(myTotal)}</td></tr>`
  }).join('')

  const projRows = quotas.map(q => {
    const parts = quotaParticipants(q, students)
    const exp   = q.amount * parts.length
    const paid  = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length * q.amount
    const pct   = exp > 0 ? Math.round((paid / exp) * 100) : 0
    return `<tr>
      <td style="padding:7px 10px;font-weight:600;">${q.name}</td>
      <td style="padding:7px 10px;text-align:center;">${parts.length} de ${students.length}</td>
      <td style="padding:7px 10px;text-align:right;">${clp(exp)}</td>
      <td style="padding:7px 10px;text-align:right;color:#059669;font-weight:600;">${clp(paid)}</td>
      <td style="padding:7px 10px;text-align:right;color:#dc2626;">${clp(exp - paid)}</td>
      <td style="padding:7px 10px;text-align:center;font-weight:700;color:${pct === 100 ? '#059669' : pct >= 60 ? '#5b4df5' : '#d97706'}">${pct}%</td>
    </tr>`
  }).join('')

  const expRows = expenses.map(e => `
    <tr>
      <td style="padding:7px 10px;">${e.description}</td>
      <td style="padding:7px 10px;">${e.category}</td>
      <td style="padding:7px 10px;text-align:right;font-weight:600;color:#dc2626;">-${clp(e.amount)}</td>
      <td style="padding:7px 10px;color:#888;">${dateF(e.date)}</td>
    </tr>`).join('')

  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"/>
<title>Informe Tesorería</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@700;900&family=Instrument+Sans:wght@400;600;700&display=swap');
  *{box-sizing:border-box;margin:0;padding:0;}
  body{font-family:'Instrument Sans',sans-serif;color:#0d0d12;background:#fff;padding:40px 48px;font-size:13px;}
  h1{font-family:'Fraunces',serif;font-size:28px;font-weight:900;letter-spacing:-0.03em;margin-bottom:2px;}
  h2{font-family:'Fraunces',serif;font-size:16px;font-weight:700;margin:28px 0 12px;border-bottom:2px solid #e8e7f0;padding-bottom:6px;}
  .meta{color:#888;font-size:12px;margin-bottom:24px;}
  .kpis{display:flex;gap:16px;margin-bottom:24px;}
  .kpi{flex:1;border-radius:10px;padding:14px 16px;}
  .kpi label{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:0.07em;display:block;margin-bottom:4px;}
  .kpi span{font-family:'Fraunces',serif;font-size:22px;font-weight:900;}
  .ki{background:#ede9ff;color:#5b4df5;} .kg{background:#d1fae5;color:#059669;}
  .kr{background:#fee2e2;color:#dc2626;} .ka{background:#fef3c7;color:#d97706;}
  table{width:100%;border-collapse:collapse;margin-bottom:8px;}
  th{background:#f5f4fa;text-align:left;padding:8px 10px;font-size:10px;text-transform:uppercase;letter-spacing:0.05em;color:#8886a0;}
  td{padding:8px 10px;border-bottom:1px solid #f3f3f8;}
  tr:last-child td{border-bottom:none;}
  .prog{height:6px;background:#e8e7f0;border-radius:99px;overflow:hidden;margin-top:10px;}
  .prog div{height:100%;border-radius:99px;}
  .footer{margin-top:36px;border-top:1px solid #e8e7f0;padding-top:12px;font-size:10px;color:#aaa;display:flex;justify-content:space-between;}
  @media print{body{padding:20px 28px;}}
</style></head><body>
  <h1>Tesorería Curso</h1>
  <div class="meta">Generado el ${today}</div>
  <div class="kpis">
    <div class="kpi ki"><label>Saldo disponible</label><span>${clp(balance)}</span></div>
    <div class="kpi kg"><label>Total recaudado</label><span>${clp(totalIncome)}</span></div>
    <div class="kpi kr"><label>Total gastado</label><span>${clp(totalExpense)}</span></div>
    <div class="kpi ka"><label>Esperado total</label><span>${clp(totalExpected)}</span></div>
  </div>
  <div class="prog"><div style="width:${globalPct}%;background:${globalPct >= 80 ? '#059669' : globalPct >= 50 ? '#5b4df5' : '#d97706'};"></div></div>
  <p style="font-size:11px;color:#888;margin-top:5px;margin-bottom:24px;">Avance: <strong style="color:#0d0d12">${globalPct}%</strong></p>
  <h2>Estado de pagos por alumno</h2>
  <table><thead><tr><th style="min-width:140px;">Alumno</th>${qHeaders}<th style="text-align:center;">Total pagado</th></tr></thead><tbody>${rows}</tbody></table>
  <h2>Proyección por cuota</h2>
  <table><thead><tr><th>Cuota</th><th style="text-align:center;">Participantes</th><th style="text-align:right;">Esperado</th><th style="text-align:right;">Recaudado</th><th style="text-align:right;">Por cobrar</th><th style="text-align:center;">Avance</th></tr></thead><tbody>${projRows}</tbody></table>
  <h2>Gastos registrados</h2>
  <table><thead><tr><th>Descripción</th><th>Categoría</th><th style="text-align:right;">Monto</th><th>Fecha</th></tr></thead>
  <tbody>${expRows}</tbody>
  <tfoot><tr><td colspan="2" style="font-weight:700;padding:10px;">Total gastado</td><td style="text-align:right;font-weight:700;color:#dc2626;padding:10px;">-${clp(totalExpense)}</td><td></td></tr></tfoot></table>
  <div class="footer"><span>Tesorería Curso</span><span>${today}</span></div>
</body></html>`

  const win = window.open('', '_blank')!
  win.document.write(html)
  win.document.close()
  win.onload = () => win.print()
}

// ─── MODAL ────────────────────────────────────────────────────
function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="overlay">
      <div className="modal">
        <div className="modal-header">
          <div className="modal-title">{title}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        {children}
      </div>
    </div>
  )
}

// ─── STUDENT PICKER ───────────────────────────────────────────
function StudentPicker({ students, selected, onChange }: { students: Student[]; selected: string[]; onChange: (v: string[]) => void }) {
  const toggle = (id: string) =>
    onChange(selected.includes(id) ? selected.filter(s => s !== id) : [...selected, id])
  return (
    <div>
      <div className="check-all">
        <button type="button" className="check-tag" onClick={() => onChange(students.map(s => s.id))}>Todos</button>
        <button type="button" className="check-tag" onClick={() => onChange([])}>Ninguno</button>
      </div>
      <div className="check-grid">
        {students.map(s => (
          <label key={s.id} className={`check-item ${selected.includes(s.id) ? 'checked' : ''}`}>
            <input type="checkbox" checked={selected.includes(s.id)} onChange={() => toggle(s.id)} />
            {s.name}
          </label>
        ))}
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// COMPONENTE PRINCIPAL
// ─────────────────────────────────────────────────────────────
export function TesoreraDashboard({
  user,
  initialStudents, initialQuotas, initialPayments,
  initialExpenses, initialApoderados,
}: Props) {
  const [tab,        setTab]        = useState('resumen')
  const [students,   setStudents]   = useState(initialStudents)
  const [quotas,     setQuotas]     = useState(initialQuotas)
  const [payments,   setPayments]   = useState(initialPayments)
  const [expenses,   setExpenses]   = useState(initialExpenses)
  const [apoderados, setApoderados] = useState(initialApoderados)
  const [modal,      setModal]      = useState<string | null>(null)
  const [form,       setForm]       = useState<Record<string, any>>({})
  const [err,        setErr]        = useState('')
  const [isPending,  startTransition] = useTransition()

  const setF = (k: string, v: any) => setForm(f => ({ ...f, [k]: v }))
  const openModal = (name: string, initial: Record<string, any> = {}) => {
    setForm(initial); setErr(''); setModal(name)
  }
  const closeModal = () => { setModal(null); setErr('') }

  // ── Cálculos ───────────────────────────────────────────────
  const totalIncome  = useMemo(() => payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0), [payments, quotas])
  const totalExpense = useMemo(() => expenses.reduce((s, e) => s + e.amount, 0), [expenses])
  const balance      = totalIncome - totalExpense

  const projection = useMemo(() => quotas.map(q => {
    const parts    = quotaParticipants(q, students)
    const expected = q.amount * parts.length
    const paid     = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length * q.amount
    const pct      = expected > 0 ? Math.round((paid / expected) * 100) : 0
    return { ...q, parts, expected, paid, pct, missing: expected - paid }
  }), [quotas, payments, students])

  const totalExpected = projection.reduce((s, p) => s + p.expected, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0

  const hasPaid = useCallback((sid: string, qid: string) =>
    payments.some(p => p.student_id === sid && p.quota_id === qid), [payments])

  // ── Acciones ───────────────────────────────────────────────
  const run = (fn: () => Promise<any>, onOk: () => void) => {
    startTransition(async () => {
      const res = await fn()
      if (res?.error) { setErr(res.error); return }
      onOk()
      closeModal()
    })
  }

  const handleSaveQuota = () => {
    const participant_ids: string[] | null =
      form.q_type === 'especial'
        ? (form.q_all ? null : (form.q_participants?.length ? form.q_participants : null))
        : null
    run(
      () => createQuotaAction({ name: form.q_name, type: form.q_type as QuotaType, amount: Number(form.q_amount), due_date: form.q_due_date, participant_ids }),
      () => setQuotas(qs => [...qs, { id: 'tmp-' + Date.now(), course_id: user.id, name: form.q_name, type: form.q_type, amount: Number(form.q_amount), due_date: form.q_due_date || null, participant_ids, created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteQuota = (id: string) => {
    run(() => deleteQuotaAction(id), () => setQuotas(qs => qs.filter(q => q.id !== id)))
  }

  const handleSavePago = () => {
    run(
      () => createPaymentAction({ student_id: form.student_id, quota_id: form.quota_id, paid_at: form.paid_at || nowDate() }),
      () => setPayments(ps => [...ps, { id: 'tmp-' + Date.now(), course_id: user.id, student_id: form.student_id, quota_id: form.quota_id, paid_at: form.paid_at || nowDate(), created_by: user.id, created_at: new Date().toISOString() }])
    )
  }

  const handleDeletePago = (id: string) => {
    run(() => deletePaymentAction(id), () => setPayments(ps => ps.filter(p => p.id !== id)))
  }

  const handleSaveExpense = () => {
    run(
      () => createExpenseAction({ description: form.e_desc, amount: Number(form.e_amount), category: form.e_category || 'Otro', date: form.e_date || nowDate() }),
      () => setExpenses(es => [...es, { id: 'tmp-' + Date.now(), course_id: user.id, description: form.e_desc, amount: Number(form.e_amount), category: form.e_category || 'Otro', date: form.e_date || nowDate(), created_by: user.id, created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteExpense = (id: string) => {
    run(() => deleteExpenseAction(id), () => setExpenses(es => es.filter(e => e.id !== id)))
  }

  const handleSaveStudent = () => {
    if (!form.s_name?.trim()) return
    run(
      () => createStudentAction(form.s_name.trim()),
      () => setStudents(ss => [...ss, { id: 'tmp-' + Date.now(), course_id: user.id, name: form.s_name.trim(), created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteStudent = (id: string) => {
    run(() => deleteStudentAction(id), () => setStudents(ss => ss.filter(s => s.id !== id)))
  }

  const handleSaveApoderado = () => {
    const fd = new FormData()
    fd.append('username', form.ap_user || '')
    fd.append('display_name', form.ap_name || '')
    fd.append('password', form.ap_pass || '')
    fd.append('student_ids', JSON.stringify(form.ap_students || []))
    run(
      () => createApoderadoAction(fd),
      () => {
        const hijos = students.filter(s => (form.ap_students || []).includes(s.id))
        setApoderados(ap => [...ap, { id: 'tmp-' + Date.now(), auth_id: '', course_id: user.id, username: form.ap_user, display_name: form.ap_name, role: 'apoderado', must_change_password: true, created_at: new Date().toISOString(), students: hijos }])
      }
    )
  }

  const handleDeleteApoderado = (id: string) => {
    run(() => deleteApoderadoAction(id), () => setApoderados(ap => ap.filter(a => a.id !== id)))
  }

  const handleResetApoderado = (id: string) => {
    run(() => resetApoderadoPasswordAction(id), () => setApoderados(ap => ap.map(a => a.id === id ? { ...a, must_change_password: true } : a)))
  }

  // ── Cuota en modal pago ────────────────────────────────────
  const quotaForPago    = form.quota_id ? quotas.find(q => q.id === form.quota_id) : null
  const eligibleForPago = quotaForPago ? quotaParticipants(quotaForPago, students) : students.map(s => s.id)

  const TABS = [
    { id: 'resumen',    label: 'Resumen' },
    { id: 'cuotas',     label: 'Cuotas' },
    { id: 'pagos',      label: 'Pagos' },
    { id: 'gastos',     label: 'Gastos' },
    { id: 'proyeccion', label: 'Proyección' },
    { id: 'alumnos',    label: 'Alumnos' },
    { id: 'apoderados', label: 'Apoderados' },
  ]

  return (
    <div>
      {/* TOPBAR */}
      <div className="topbar no-print">
        <div>
          <div className="topbar-title">🏦 Tesorería <span>Curso</span></div>
          <div className="topbar-sub">Vista Tesorera · {user.display_name}</div>
        </div>
        <nav className="topbar-nav">
          {TABS.map(t => (
            <button key={t.id} className={`nav-btn ${tab === t.id ? 'active' : 'inactive'}`} onClick={() => setTab(t.id)}>
              {t.label}
            </button>
          ))}
        </nav>
        <div className="topbar-right">
          <button className="btn btn-green btn-sm" onClick={() => generatePDF(students, quotas, payments, expenses)}>📄 PDF</button>
          <button className="btn btn-ghost btn-sm" onClick={() => startTransition(() => logoutAction())}>Salir</button>
        </div>
      </div>

      <div className="content">

        {/* ══ RESUMEN ══ */}
        {tab === 'resumen' && (
          <>
            <div className="card-grid card-grid-3 mb-4">
              {[
                { label: 'Saldo disponible', value: clp(balance),      cls: 'kpi-indigo', sub: `${totalIncome > 0 ? Math.round(balance / totalIncome * 100) : 0}% de lo recaudado` },
                { label: 'Total recaudado',  value: clp(totalIncome),  cls: 'kpi-green',  sub: `${payments.length} pagos registrados` },
                { label: 'Total gastado',    value: clp(totalExpense), cls: 'kpi-red',    sub: `${expenses.length} gastos` },
              ].map(k => (
                <div key={k.label} className={`kpi ${k.cls}`}>
                  <div className="kpi-label">{k.label}</div>
                  <div className="kpi-value">{k.value}</div>
                  <div className="kpi-sub">{k.sub}</div>
                </div>
              ))}
            </div>
            <div className="card-grid card-grid-2 mb-4">
              <div className="card">
                <div className="card-title">Últimos pagos</div>
                <table className="tbl">
                  <thead><tr><th>Alumno</th><th>Cuota</th><th>Fecha</th></tr></thead>
                  <tbody>
                    {[...payments].reverse().slice(0, 6).map(p => {
                      const q = quotas.find(q => q.id === p.quota_id)
                      const s = students.find(s => s.id === p.student_id)
                      return (
                        <tr key={p.id}>
                          <td className="fw-700 fs-13">{s?.name}</td>
                          <td><span className={`badge ${q?.type === 'especial' ? 'badge-blue' : 'badge-indigo'}`}>{q?.name}</span></td>
                          <td className="fs-12 c-muted">{dateF(p.paid_at)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              <div className="card">
                <div className="card-title">Últimos gastos</div>
                <table className="tbl">
                  <thead><tr><th>Descripción</th><th>Monto</th><th>Fecha</th></tr></thead>
                  <tbody>
                    {[...expenses].reverse().slice(0, 6).map(e => (
                      <tr key={e.id}>
                        <td className="fw-700 fs-13">{e.description}</td>
                        <td className="fw-700 c-red">-{clp(e.amount)}</td>
                        <td className="fs-12 c-muted">{dateF(e.date)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="card">
              <div className="row mb-4">
                <div className="card-title" style={{ marginBottom: 0 }}>Recaudación global</div>
                <span className="fw-700 fs-13 c-indigo">{globalPct}% del esperado</span>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${globalPct}%`, background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)' }} />
              </div>
              <div className="row mt-3">
                <span className="fs-12 c-muted">Esperado: {clp(totalExpected)}</span>
                <span className="fs-12 c-muted">Por cobrar: <strong className="c-red">{clp(totalExpected - totalIncome)}</strong></span>
              </div>
            </div>
          </>
        )}

        {/* ══ CUOTAS ══ */}
        {tab === 'cuotas' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Cuotas definidas</div>
              <button className="btn btn-primary" onClick={() => openModal('quota', { q_participants: [] })}>+ Nueva cuota</button>
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Tipo</th><th>Monto</th><th>Participantes</th><th>Vencimiento</th><th>Recaudado</th><th>Estado</th><th></th></tr></thead>
              <tbody>
                {quotas.map(q => {
                  const parts     = quotaParticipants(q, students)
                  const paidCount = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length
                  const pending   = parts.length - paidCount
                  return (
                    <tr key={q.id}>
                      <td className="fw-700 fs-13">{q.name}</td>
                      <td><span className={`badge ${q.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>{q.type === 'mensual' ? 'Mensual' : 'Especial'}</span></td>
                      <td className="fw-700 c-green">{clp(q.amount)}</td>
                      <td><span className="badge badge-gray">{q.participant_ids === null ? `Todo el curso (${students.length})` : `${parts.length} de ${students.length}`}</span></td>
                      <td className="fs-12 c-muted">{dateF(q.due_date)}</td>
                      <td className="fw-700 c-green">{clp(paidCount * q.amount)}</td>
                      <td><span className={`badge ${pending > 0 ? 'badge-amber' : 'badge-green'}`}>{pending > 0 ? `${pending} pendiente${pending > 1 ? 's' : ''}` : '✓ Completo'}</span></td>
                      <td><button className="btn-red-sm" onClick={() => handleDeleteQuota(q.id)}>Eliminar</button></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* ══ PAGOS ══ */}
        {tab === 'pagos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Estado de pagos por alumno</div>
              <button className="btn btn-primary" onClick={() => openModal('pago')}>+ Registrar pago</button>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="tbl">
                <thead>
                  <tr>
                    <th style={{ minWidth: 150 }}>Alumno</th>
                    {quotas.map(q => (
                      <th key={q.id} style={{ minWidth: 110, textAlign: 'center' }}>
                        {q.name}
                        <div style={{ fontWeight: 400, color: 'var(--muted)', marginTop: 1, fontSize: 9 }}>
                          {q.participant_ids === null ? 'Todos' : `${q.participant_ids.length} alumnos`}
                        </div>
                      </th>
                    ))}
                    <th style={{ textAlign: 'center' }}>Total pagado</th>
                  </tr>
                </thead>
                <tbody>
                  {students.map(s => {
                    const myPays = payments.filter(p => p.student_id === s.id)
                    const total  = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
                    return (
                      <tr key={s.id}>
                        <td className="fw-700 fs-13">{s.name}</td>
                        {quotas.map(q => {
                          const belongs = isParticipant(q, s.id, students)
                          const paid    = hasPaid(s.id, q.id)
                          const pay     = myPays.find(p => p.quota_id === q.id)
                          return (
                            <td key={q.id} style={{ textAlign: 'center' }}>
                              {!belongs
                                ? <span className="badge badge-gray">No aplica</span>
                                : paid
                                  ? <button className="badge badge-green" style={{ cursor: 'pointer', border: 'none' }} title={`Pagado ${dateF(pay?.paid_at)}`} onClick={() => pay && handleDeletePago(pay.id)}>✓ Pagado</button>
                                  : <span className="badge badge-red">Pendiente</span>
                              }
                            </td>
                          )
                        })}
                        <td style={{ textAlign: 'center' }} className="fw-700 c-indigo">{clp(total)}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <p style={{ fontSize: 10, color: 'var(--muted)', marginTop: 10 }}>💡 Haz clic en "✓ Pagado" para anular un pago.</p>
          </div>
        )}

        {/* ══ GASTOS ══ */}
        {tab === 'gastos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Gastos registrados</div>
              <button className="btn btn-danger" onClick={() => openModal('gasto')}>+ Registrar gasto</button>
            </div>
            {balance < 0 && <div className="alert alert-red">⚠️ Saldo negativo: los gastos superan lo recaudado en {clp(Math.abs(balance))}.</div>}
            {balance >= 0 && balance < totalExpense * 0.2 && totalExpense > 0 && <div className="alert alert-amber">⚠️ Saldo bajo: quedan {clp(balance)} disponibles.</div>}
            <table className="tbl">
              <thead><tr><th>Descripción</th><th>Categoría</th><th>Monto</th><th>Fecha</th><th></th></tr></thead>
              <tbody>
                {[...expenses].reverse().map(e => (
                  <tr key={e.id}>
                    <td className="fw-700 fs-13">{e.description}</td>
                    <td><span className="badge badge-indigo">{e.category}</span></td>
                    <td className="fw-700 c-red">-{clp(e.amount)}</td>
                    <td className="fs-12 c-muted">{dateF(e.date)}</td>
                    <td><button className="btn-red-sm" onClick={() => handleDeleteExpense(e.id)}>Eliminar</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {expenses.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', fontSize: 13, padding: '20px 0' }}>Sin gastos registrados</div>}
            <div className="divider" />
            <div className="row"><span className="fs-13 c-muted">Total gastado</span><span className="fw-700 c-red" style={{ fontSize: 17, fontFamily: "'Fraunces',serif" }}>{clp(totalExpense)}</span></div>
            <div className="row mt-3"><span className="fs-13 c-muted">Saldo disponible</span><span className="fw-700" style={{ fontSize: 17, fontFamily: "'Fraunces',serif", color: balance >= 0 ? 'var(--green)' : 'var(--red)' }}>{clp(balance)}</span></div>
          </div>
        )}

        {/* ══ PROYECCIÓN ══ */}
        {tab === 'proyeccion' && (
          <>
            <div className="card-grid card-grid-3 mb-4">
              <div className="kpi kpi-indigo"><div className="kpi-label">Recaudación esperada</div><div className="kpi-value">{clp(totalExpected)}</div><div className="kpi-sub">Según participantes</div></div>
              <div className="kpi kpi-green"><div className="kpi-label">Recaudado hasta hoy</div><div className="kpi-value">{clp(totalIncome)}</div><div className="kpi-sub">{globalPct}% del esperado</div></div>
              <div className="kpi kpi-amber"><div className="kpi-label">Falta por recaudar</div><div className="kpi-value">{clp(totalExpected - totalIncome)}</div><div className="kpi-sub">{100 - globalPct}% pendiente</div></div>
            </div>
            <div className="card mb-4">
              <div className="row mb-3"><div className="card-title" style={{ marginBottom: 0 }}>Avance global</div><span className="fw-700 c-indigo">{globalPct}%</span></div>
              <div className="progress-bar" style={{ height: 12 }}>
                <div className="progress-fill" style={{ width: `${globalPct}%`, background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)' }} />
              </div>
            </div>
            <div className="card">
              <div className="card-title">Por cuota</div>
              {projection.map(p => (
                <div key={p.id} style={{ marginBottom: 22 }}>
                  <div className="row mb-3">
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                      <span className="fw-700 fs-13">{p.name}</span>
                      <span className={`badge ${p.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>{p.type === 'mensual' ? 'Mensual' : 'Especial'}</span>
                      <span className="badge badge-gray">👥 {p.participant_ids === null ? 'Todo el curso' : `${p.parts.length} de ${students.length}`}</span>
                    </div>
                    <span className="fw-700 fs-13 c-indigo">{p.pct}%</span>
                  </div>
                  <div className="progress-bar">
                    <div className="progress-fill" style={{ width: `${p.pct}%`, background: p.pct === 100 ? 'var(--green)' : p.pct >= 60 ? 'var(--indigo)' : 'var(--amber)' }} />
                  </div>
                  <div className="row mt-3" style={{ fontSize: 11, color: 'var(--muted)' }}>
                    <span>Esperado: {clp(p.expected)} · Recaudado: <strong style={{ color: 'var(--green)' }}>{clp(p.paid)}</strong></span>
                    <span style={{ color: 'var(--red)' }}>Falta: <strong>{clp(p.missing)}</strong></span>
                  </div>
                </div>
              ))}
              <div className="divider" />
              <div style={{ background: 'var(--bg)', borderRadius: 10, padding: '14px 16px' }}>
                {[
                  { label: 'Recaudación esperada', val: clp(totalExpected), color: 'var(--ink)' },
                  { label: 'Ya recaudado', val: clp(totalIncome), color: 'var(--green)' },
                  { label: 'Por recaudar', val: clp(totalExpected - totalIncome), color: 'var(--amber)' },
                  { label: 'Total gastado', val: clp(totalExpense), color: 'var(--red)' },
                  { label: 'Saldo actual', val: clp(balance), color: balance >= 0 ? 'var(--green)' : 'var(--red)' },
                  { label: 'Saldo proyectado (si todos pagan)', val: clp(totalExpected - totalExpense), color: totalExpected >= totalExpense ? 'var(--green)' : 'var(--red)' },
                ].map(r => (
                  <div key={r.label} className="row mb-3">
                    <span className="fs-13 c-muted">{r.label}</span>
                    <span className="fw-700 fs-13" style={{ color: r.color, fontFamily: "'Fraunces',serif" }}>{r.val}</span>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}

        {/* ══ ALUMNOS ══ */}
        {tab === 'alumnos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Alumnos del curso ({students.length})</div>
              <button className="btn btn-primary" onClick={() => openModal('alumno')}>+ Agregar alumno</button>
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Cuotas pagadas</th><th>Total pagado</th><th></th></tr></thead>
              <tbody>
                {students.map(s => {
                  const myPays   = payments.filter(p => p.student_id === s.id)
                  const myTotal  = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
                  return (
                    <tr key={s.id}>
                      <td className="fw-700 fs-13">{s.name}</td>
                      <td><span className="badge badge-indigo">{myPays.length} pagos</span></td>
                      <td className="fw-700 c-green">{clp(myTotal)}</td>
                      <td><button className="btn-red-sm" onClick={() => handleDeleteStudent(s.id)}>Eliminar</button></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* ══ APODERADOS ══ */}
        {tab === 'apoderados' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Gestión de apoderados</div>
              <button className="btn btn-primary" onClick={() => openModal('apoderado', { ap_students: [] })}>+ Crear apoderado</button>
            </div>
            <div className="alert alert-blue mb-4">
              ℹ️ La contraseña inicial se entrega al apoderado. Al primer ingreso, el sistema le pedirá que la cambie.
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Usuario</th><th>Alumno(s)</th><th>Estado</th><th>Acciones</th></tr></thead>
              <tbody>
                {apoderados.map(a => (
                  <tr key={a.id}>
                    <td className="fw-700 fs-13">{a.display_name}</td>
                    <td className="fs-12 c-muted" style={{ fontFamily: 'monospace' }}>{a.username}</td>
                    <td>{a.students?.map(h => <span key={h.id} className="badge badge-indigo" style={{ marginRight: 3 }}>{h.name}</span>)}</td>
                    <td><span className={`badge ${a.must_change_password ? 'badge-amber' : 'badge-green'}`}>{a.must_change_password ? 'Debe cambiar clave' : 'Activo'}</span></td>
                    <td style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-ghost btn-sm" onClick={() => handleResetApoderado(a.id)}>Reset clave</button>
                      <button className="btn-red-sm" onClick={() => handleDeleteApoderado(a.id)}>Eliminar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ══ MODALES ══ */}

      {modal === 'quota' && (
        <Modal title="Nueva cuota" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre</label>
          <input className="form-input" placeholder="ej: Cuota Junio" value={form.q_name || ''} onChange={e => setF('q_name', e.target.value)} />
          <label className="form-label">Tipo</label>
          <select className="form-input" value={form.q_type || ''} onChange={e => { setF('q_type', e.target.value); setF('q_participants', []); setF('q_all', false) }}>
            <option value="">— seleccionar —</option>
            <option value="mensual">Mensual (todo el curso)</option>
            <option value="especial">Especial (viaje, evento…)</option>
          </select>
          {form.q_type === 'especial' && (
            <div style={{ marginBottom: 12 }}>
              <label className="form-label">¿Quiénes participan?</label>
              <div style={{ display: 'flex', gap: 12, marginBottom: 10 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
                  <input type="radio" name="q_scope" checked={!!form.q_all} onChange={() => { setF('q_all', true); setF('q_participants', []) }} /> Todo el curso
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
                  <input type="radio" name="q_scope" checked={!form.q_all} onChange={() => setF('q_all', false)} /> Seleccionar alumnos
                </label>
              </div>
              {!form.q_all && <StudentPicker students={students} selected={form.q_participants || []} onChange={v => setF('q_participants', v)} />}
              {!form.q_all && (form.q_participants || []).length > 0 && <div className="alert alert-blue" style={{ fontSize: 11 }}>{(form.q_participants || []).length} alumno(s) seleccionados</div>}
            </div>
          )}
          <label className="form-label">Monto por alumno (CLP)</label>
          <input className="form-input" type="number" min="1" value={form.q_amount || ''} onChange={e => setF('q_amount', e.target.value)} />
          {form.q_amount && (
            <div className="alert alert-green" style={{ fontSize: 11 }}>
              Recaudación esperada: <strong>{clp(Number(form.q_amount) * (form.q_type === 'mensual' || form.q_all ? students.length : (form.q_participants || []).length))}</strong>
            </div>
          )}
          <label className="form-label">Vencimiento (opcional)</label>
          <input className="form-input" type="date" value={form.q_due_date || ''} onChange={e => setF('q_due_date', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.q_name || !form.q_amount || !form.q_type || (form.q_type === 'especial' && !form.q_all && !(form.q_participants || []).length)} onClick={handleSaveQuota}>
              {isPending ? 'Guardando…' : 'Crear cuota'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'pago' && (
        <Modal title="Registrar pago" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Cuota</label>
          <select className="form-input" value={form.quota_id || ''} onChange={e => { setF('quota_id', e.target.value); setF('student_id', '') }}>
            <option value="">— seleccionar —</option>
            {quotas.map(q => <option key={q.id} value={q.id}>{q.name} — {clp(q.amount)}</option>)}
          </select>
          <label className="form-label">Alumno</label>
          <select className="form-input" value={form.student_id || ''} onChange={e => setF('student_id', e.target.value)} disabled={!form.quota_id}>
            <option value="">— seleccionar —</option>
            {students.filter(s => eligibleForPago.includes(s.id)).map(s => {
              const paid = hasPaid(s.id, form.quota_id)
              return <option key={s.id} value={s.id} disabled={paid}>{s.name}{paid ? ' ✓ ya pagó' : ''}</option>
            })}
          </select>
          {quotaForPago?.participant_ids !== null && form.quota_id && (
            <div className="alert alert-blue" style={{ fontSize: 11 }}>Esta cuota aplica solo a {quotaParticipants(quotaForPago!, students).length} de {students.length} alumnos.</div>
          )}
          <label className="form-label">Fecha de pago</label>
          <input className="form-input" type="date" value={form.paid_at || nowDate()} onChange={e => setF('paid_at', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.student_id || !form.quota_id || hasPaid(form.student_id, form.quota_id)} onClick={handleSavePago}>
              {isPending ? 'Guardando…' : 'Registrar'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'gasto' && (
        <Modal title="Registrar gasto" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          {balance <= 0 && <div className="alert alert-amber">⚠️ Saldo actual: {clp(balance)}.</div>}
          <label className="form-label">Descripción</label>
          <input className="form-input" value={form.e_desc || ''} onChange={e => setF('e_desc', e.target.value)} />
          <label className="form-label">Categoría</label>
          <select className="form-input" value={form.e_category || ''} onChange={e => setF('e_category', e.target.value)}>
            <option value="">— seleccionar —</option>
            {['Material', 'Reunión', 'Evento', 'Viaje', 'Otro'].map(c => <option key={c}>{c}</option>)}
          </select>
          <label className="form-label">Monto (CLP)</label>
          <input className="form-input" type="number" min="1" value={form.e_amount || ''} onChange={e => setF('e_amount', e.target.value)} />
          {form.e_amount && <div className="alert alert-green" style={{ fontSize: 11 }}>Saldo después: <strong>{clp(balance - Number(form.e_amount))}</strong></div>}
          <label className="form-label">Fecha</label>
          <input className="form-input" type="date" value={form.e_date || nowDate()} onChange={e => setF('e_date', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-danger" disabled={isPending || !form.e_desc || !form.e_amount} onClick={handleSaveExpense}>
              {isPending ? 'Guardando…' : 'Registrar gasto'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'alumno' && (
        <Modal title="Agregar alumno" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre completo</label>
          <input className="form-input" placeholder="ej: Valentina Mora" value={form.s_name || ''} onChange={e => setF('s_name', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.s_name?.trim()} onClick={handleSaveStudent}>
              {isPending ? 'Guardando…' : 'Agregar'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'apoderado' && (
        <Modal title="Crear apoderado" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre completo</label>
          <input className="form-input" placeholder="ej: María González" value={form.ap_name || ''} onChange={e => setF('ap_name', e.target.value)} />
          <label className="form-label">Nombre de usuario</label>
          <input className="form-input" placeholder="ej: mgonzalez (sin espacios)" value={form.ap_user || ''} onChange={e => setF('ap_user', e.target.value.toLowerCase().replace(/\s/g, ''))} />
          <label className="form-label">Contraseña inicial</label>
          <input className="form-input" placeholder="El apoderado deberá cambiarla al ingresar" value={form.ap_pass || ''} onChange={e => setF('ap_pass', e.target.value)} />
          <label className="form-label">Alumno(s) asociado(s)</label>
          <StudentPicker students={students} selected={form.ap_students || []} onChange={v => setF('ap_students', v)} />
          {!(form.ap_students || []).length && <div className="alert alert-amber" style={{ fontSize: 11 }}>Debes seleccionar al menos un alumno.</div>}
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.ap_name || !form.ap_user || !form.ap_pass || !(form.ap_students || []).length} onClick={handleSaveApoderado}>
              {isPending ? 'Creando…' : 'Crear apoderado'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  )
}

