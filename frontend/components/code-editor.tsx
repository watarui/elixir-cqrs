"use client"

import React, { useEffect, useRef } from 'react'
import { EditorView, basicSetup } from 'codemirror'
import { EditorState } from '@codemirror/state'
import { json } from '@codemirror/lang-json'
import { javascript } from '@codemirror/lang-javascript'
import { oneDark } from '@codemirror/theme-one-dark'

interface CodeEditorProps {
  value: string
  onChange: (value: string) => void
  language?: 'json' | 'graphql'
  placeholder?: string
  height?: string
  readOnly?: boolean
  theme?: 'light' | 'dark'
}

export default function CodeEditor({
  value,
  onChange,
  language = 'json',
  placeholder,
  height = '200px',
  readOnly = false,
  theme = 'dark'
}: CodeEditorProps) {
  const editorRef = useRef<HTMLDivElement>(null)
  const viewRef = useRef<EditorView | null>(null)

  useEffect(() => {
    if (!editorRef.current) return

    const extensions = [
      basicSetup,
      EditorView.updateListener.of((update) => {
        if (update.docChanged && !readOnly) {
          onChange(update.state.doc.toString())
        }
      }),
      EditorState.readOnly.of(readOnly),
      EditorView.theme({
        "&": {
          height: height,
          fontSize: "14px"
        },
        ".cm-content": {
          padding: "12px",
          fontFamily: "'JetBrains Mono', Consolas, Monaco, 'Courier New', monospace"
        },
        ".cm-focused .cm-cursor": {
          borderLeftColor: "#528bff"
        },
        ".cm-placeholder": {
          color: "#888",
          fontStyle: "italic"
        },
        "&.cm-editor.cm-focused": {
          outline: "none"
        }
      })
    ]

    // Language support
    if (language === 'json') {
      extensions.push(json())
    } else if (language === 'graphql') {
      // GraphQL syntax highlighting using JavaScript mode as a fallback
      extensions.push(javascript())
    }

    // Theme
    if (theme === 'dark') {
      extensions.push(oneDark)
    }

    // Placeholder
    if (placeholder && !value) {
      extensions.push(EditorView.placeholder(placeholder))
    }

    const state = EditorState.create({
      doc: value,
      extensions
    })

    const view = new EditorView({
      state,
      parent: editorRef.current
    })

    viewRef.current = view

    return () => {
      view.destroy()
    }
  }, [language, placeholder, height, readOnly, theme])

  // Update content when value prop changes
  useEffect(() => {
    if (viewRef.current && value !== viewRef.current.state.doc.toString()) {
      viewRef.current.dispatch({
        changes: {
          from: 0,
          to: viewRef.current.state.doc.length,
          insert: value
        }
      })
    }
  }, [value])

  return <div ref={editorRef} className="border rounded-md overflow-hidden" />
}