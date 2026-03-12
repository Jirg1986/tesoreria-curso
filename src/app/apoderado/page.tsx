// src/app/apoderado/page.tsx

import { redirect } from 'next/navigation'
import { getCurrentAppUser } from '@/actions/auth'
import { getApoderadoDataAction } from '@/actions/data'
import { ApoderadoDashboard } from '@/components/ApoderadoDashboard'

export default async function ApoderadoPage() {
  const user = await getCurrentAppUser()
  if (!user) redirect('/login')
  if (user.role !== 'apoderado') redirect('/dashboard')
  if (user.must_change_password) redirect('/change-password')

  const data = await getApoderadoDataAction()
  if (!data) redirect('/login')

  return <ApoderadoDashboard data={data} />
}

