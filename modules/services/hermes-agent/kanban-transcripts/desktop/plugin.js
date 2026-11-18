// Kanban transcripts: a "Transcripts" list at the bottom of the Kanban task modal's sidebar opens
// each worker run's read-only HTML export in a near-fullscreen dialog.
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  SandboxedFrame,
  STATUSBAR_AREAS,
  atom,
  useValue
} from '@hermes/plugin-sdk'
import { useEffect, useState } from 'react'
import { jsx, jsxs } from 'react/jsx-runtime'

// The SDK has no area in the task modal (apps/desktop/src/plugins/kanban/drawer.tsx), so the list is
// plain DOM appended to the modal's <aside>. It depends on that markup: a [data-slot="dialog-content"]
// holding a <header> with the 6-hex shortId span, a [data-slot="dialog-title"] and the sidebar <aside>.
// _work.nix greps the locked Desktop source for these anchors and fails the build when they move.
const ATTR = 'data-kanban-transcripts'
const SHORT_ID = /^[0-9a-f]{6}$/
// Desktop's FIELD_LABEL (plugins/kanban/ui.tsx), so the heading matches the sidebar's other labels.
const FIELD_LABEL = 'text-[0.62rem] font-semibold uppercase tracking-[0.14em] text-(--ui-text-quaternary)'

function findModal() {
  for (const content of document.querySelectorAll('[data-slot="dialog-content"]')) {
    const aside = content.querySelector('aside')
    const header = content.querySelector('header')
    if (!aside || !header) continue
    const short = [...header.querySelectorAll('span')].map(span => span.textContent.trim()).find(text => SHORT_ID.test(text))
    if (short) return { aside, short, title: content.querySelector('[data-slot="dialog-title"]')?.textContent.trim() ?? '' }
  }
  return null
}

const when = seconds => (seconds ? new Date(seconds * 1000).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : 'not started')

function el(tag, props, ...children) {
  const node = Object.assign(document.createElement(tag), props)
  node.append(...children)
  return node
}

function fill(section, list, body, open) {
  section.firstChild.textContent = `Transcripts (${body.runs.length})`
  if (body.runs.length === 0) return list.replaceChildren(el('li', { className: 'text-[0.75rem] text-(--ui-text-quaternary)', textContent: 'No worker runs.' }))
  list.replaceChildren(
    ...body.runs.map(run => {
      const label = `#${run.id} · ${run.profile ?? '?'} · ${when(run.started_at)} · ${run.outcome ?? run.status}`
      const button = el('button', {
        disabled: !run.session_id,
        textContent: label,
        title: run.session_id ? `Open run #${run.id}'s worker session` : 'No worker session',
        type: 'button',
        onclick: () => open({ taskId: body.task_id, run })
      })
      Object.assign(button.style, {
        background: 'none',
        border: 0,
        color: 'var(--ui-text-secondary)',
        cursor: run.session_id ? 'pointer' : 'default',
        fontSize: '0.75rem',
        opacity: run.session_id ? '1' : '0.5',
        padding: 0,
        textAlign: 'left',
        textDecoration: run.session_id ? 'underline' : 'none'
      })
      return el('li', {}, button)
    })
  )
}

function Viewer({ ctx, $open }) {
  const open = useValue($open)
  const [src, setSrc] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (!open) return
    let live = true
    setSrc(null)
    setError(null)
    ctx.rest(`/tasks/${open.taskId}/runs/${open.run.id}/html`).then(
      body => live && setSrc(body.src),
      err => live && setError(String(err))
    )
    return () => {
      live = false
    }
  }, [open])

  if (!open) return null
  const title = `Run #${open.run.id} · ${open.run.profile ?? '?'} · ${open.taskId}`
  return jsx(Dialog, {
    open: true,
    onOpenChange: next => next || $open.set(null),
    children: jsxs(DialogContent, {
      'aria-describedby': undefined,
      // The shell is a fixed-height flex column; the body (a content-sized grid by default) must
      // grow into it, and the frame wrapper into the body, or the iframe falls back to 150px.
      bodyClassName: 'flex flex-1 flex-col min-h-0 overflow-hidden',
      style: { width: '96vw', maxWidth: '96vw', height: '94vh', maxHeight: '94vh' },
      children: [
        jsx(DialogHeader, { children: jsx(DialogTitle, { children: title }) }),
        jsx('div', {
          style: { position: 'relative', flex: 1, minHeight: 0 },
          children: src
            ? jsx(SandboxedFrame, { src, title, style: { position: 'absolute', inset: 0, width: '100%', height: '100%' } })
            : jsx('div', { className: error ? 'text-sm text-destructive' : 'text-sm', children: error ?? 'Loading…' })
        })
      ]
    })
  })
}

export default {
  id: 'kanban-transcripts',
  name: 'Kanban transcripts',
  register(ctx) {
    const $open = atom(null)
    const open = value => $open.set(value)

    const sync = () => {
      const modal = findModal()
      if (!modal) return
      let section = modal.aside.querySelector(`:scope > [${ATTR}]`)
      if (!section) {
        section = el('section', { className: 'flex flex-col gap-1.5' }, el('div', { className: FIELD_LABEL, textContent: 'Transcripts' }), el('ul', { className: 'flex flex-col gap-1' }))
      }
      // React appends late sections (attachments) after ours; keep the list at the bottom.
      if (modal.aside.lastElementChild !== section) modal.aside.append(section)
      const key = `${modal.short}\n${modal.title}`
      if (section.getAttribute(ATTR) === key) return
      section.setAttribute(ATTR, key)
      const list = section.lastChild
      list.replaceChildren(el('li', { className: 'text-[0.75rem] text-(--ui-text-quaternary)', textContent: 'Loading…' }))
      ctx.rest(`/lookup?short=${modal.short}&title=${encodeURIComponent(modal.title)}`).then(
        body => section.getAttribute(ATTR) === key && fill(section, list, body, open),
        err => section.getAttribute(ATTR) === key && list.replaceChildren(el('li', { className: 'text-[0.75rem] text-destructive', textContent: String(err) }))
      )
    }

    // characterData: switching cards through a dependency chip can reuse the modal and only change its text.
    const observer = new MutationObserver(sync)
    observer.observe(document.body, { childList: true, subtree: true, characterData: true })
    ctx.onDispose(() => {
      observer.disconnect()
      for (const node of document.querySelectorAll(`[${ATTR}]`)) node.remove()
    })
    sync()

    // The status bar is always mounted; the dialog portals out of it and renders nothing while closed.
    ctx.register({ id: 'viewer', area: STATUSBAR_AREAS.right, render: () => jsx(Viewer, { ctx, $open }) })
  }
}
