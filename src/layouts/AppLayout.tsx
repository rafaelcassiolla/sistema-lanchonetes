import type { ReactNode } from 'react'
import Brand from '../components/Brand'
import { formatCurrentDate } from '../utils/formatCurrentDate'

type AppLayoutProps = {
  children: ReactNode
}

function AppLayout({ children }: AppLayoutProps) {
  return (
    <div className="min-h-screen bg-[#f7f6f2] lg:grid lg:grid-cols-[248px_1fr]">
      <aside className="hidden min-h-screen flex-col bg-stone-900 px-5 py-7 lg:flex">
        <Brand />
        <nav aria-label="Navegação principal" className="mt-12">
          <a
            aria-current="page"
            className="flex items-center gap-3 rounded-xl bg-white/10 px-3 py-2.5 text-sm font-medium text-white"
            href="#inicio"
          >
            <span aria-hidden="true" className="size-2 rounded-full bg-orange-400" />
            Início
          </a>
        </nav>
        <p className="mt-auto text-xs leading-5 text-stone-500">
          Um atendimento mais simples começa por aqui.
        </p>
      </aside>

      <div className="min-w-0">
        <header className="flex h-[76px] items-center justify-between border-b border-stone-200/80 bg-white px-5 sm:px-8 lg:px-10">
          <div className="lg:hidden">
            <Brand compact />
          </div>
          <p className="hidden text-sm font-semibold text-stone-800 lg:block">
            Início
          </p>
          <p className="text-xs font-medium capitalize text-stone-500 sm:text-sm">
            {formatCurrentDate()}
          </p>
        </header>

        <main
          id="inicio"
          className="mx-auto w-full max-w-6xl px-5 py-8 sm:px-8 sm:py-10 lg:px-10"
        >
          {children}
          <footer className="mt-10 border-t border-stone-200 pt-5 text-xs text-stone-500">
            Atendimento para Lanchonetes <span aria-hidden="true">·</span> Uma
            base feita para evoluir.
          </footer>
        </main>
      </div>
    </div>
  )
}

export default AppLayout
