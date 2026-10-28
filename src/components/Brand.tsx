type BrandProps = {
  compact?: boolean
}

function Brand({ compact = false }: BrandProps) {
  return (
    <div className="flex items-center gap-3">
      <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-orange-400 text-lg font-black text-stone-950">
        L
      </span>
      {!compact && (
        <span className="leading-tight">
          <span className="block text-sm font-bold text-white">Lanche</span>
          <span className="block text-xs text-stone-400">painel de atendimento</span>
        </span>
      )}
    </div>
  )
}

export default Brand
