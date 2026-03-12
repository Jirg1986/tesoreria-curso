// src/app/dashboard/page.tsx
// Server Component â€” carga datos y pasa al cliente

import { getDashboardDataAction } from '@/actions/data'
import { getCurrentAppUser } from '@/actions/auth'
import { TesoreraDashboard } from '@/components/TesoreraDashboard'

export default async function DashboardPage() {
  const [user, data] = await Promise.all([
    getCurrentAppUser(),
    getDashboardDataAction(),
  ])

  return (
    <TesoreraDashboard
      user={user!}
      initialStudents={data.students}
      initialQuotas={data.quotas}
      initialPayments={data.payments}
      initialExpenses={data.expenses}
      initialApoderados={data.apoderados}
    />
  )
}

