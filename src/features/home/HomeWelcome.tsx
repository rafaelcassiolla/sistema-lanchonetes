import type { HomeHighlight } from '../../types/home'

const highlights: HomeHighlight[] = [
  {
    id: 'organized',
    title: 'Uma base organizada',
    description: 'Um ponto de partida claro para construir o atendimento do seu negócio.',
  },
  {
    id: 'responsive',
    title: 'Funciona em qualquer tela',
    description: 'Uma interface responsiva para acompanhar a rotina no computador ou celular.',
  },
  {
    id: 'scalable',
    title: 'Pronta para evoluir',
    description: 'Estrutura feita com React, TypeScript e Tailwind CSS.',
  },
]

function HomeWelcome() {
  return (
    <div className="space-y-8">
      <section className="relative overflow-hidden rounded-3xl bg-stone-900 px-6 py-10 text-white sm:px-10 sm:py-14">
        <div className="relative z-10 max-w-2xl">
          <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-medium text-orange-200">
            <span className="size-1.5 rounded-full bg-orange-400" />
            Seu espaço de atendimento
          </span>
          <h1 className="mt-6 text-3xl font-semibold leading-tight tracking-tight sm:text-5xl">
            Um bom atendimento começa com uma boa base.
          </h1>
          <p className="mt-4 max-w-xl text-sm leading-7 text-stone-300 sm:text-base">
            Estamos preparando um espaço simples para ajudar sua lanchonete a
            atender melhor. Esta é a primeira etapa: uma interface organizada,
            responsiva e pronta para crescer com você.
          </p>
        </div>
        <div
          aria-hidden="true"
          className="absolute -bottom-28 -right-20 size-80 rounded-full border-[48px] border-orange-400/10 sm:-right-8"
        />
        <div
          aria-hidden="true"
          className="absolute -bottom-14 -right-6 size-48 rounded-full border border-orange-300/20"
        />
      </section>

      <section aria-labelledby="highlights-title">
        <div className="mb-4">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-orange-700">
            Primeiros passos
          </p>
          <h2
            id="highlights-title"
            className="mt-2 text-xl font-semibold tracking-tight text-stone-900"
          >
            Feito para começar com clareza
          </h2>
        </div>
        <div className="grid gap-4 md:grid-cols-3">
          {highlights.map((highlight, index) => (
            <article
              key={highlight.id}
              className="rounded-2xl border border-stone-200 bg-white p-5 shadow-sm shadow-stone-900/[0.02]"
            >
              <span className="grid size-9 place-items-center rounded-xl bg-orange-50 text-xs font-bold text-orange-700">
                {String(index + 1).padStart(2, '0')}
              </span>
              <h3 className="mt-5 text-sm font-semibold text-stone-900">
                {highlight.title}
              </h3>
              <p className="mt-2 text-sm leading-6 text-stone-500">
                {highlight.description}
              </p>
            </article>
          ))}
        </div>
      </section>
    </div>
  )
}

export default HomeWelcome
