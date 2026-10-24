export type McpTool = { name: string; description?: string }
export type McpResponse = { result?: { tools?: McpTool[]; content?: Array<{ type?: string; text?: string }>; structuredContent?: unknown }; error?: { message?: string; code?: number; data?: unknown } }

let sessionId: string | null = null
let sessionSetup: Promise<void> | null = null

function parseMcpResponse(text: string): McpResponse | null {
  if (!text.trim()) return null
  try { return JSON.parse(text) as McpResponse } catch {
    // DAB uses the streamable HTTP transport and commonly returns one SSE
    // message even for request/response calls.
    const event = text.split('\n').find((line) => line.startsWith('data:'))?.slice(5).trim()
    if (!event) throw new Error(text)
    try { return JSON.parse(event) as McpResponse } catch { throw new Error(text) }
  }
}

async function mcp(method: string, params?: Record<string, unknown>): Promise<McpResponse | null> {
  if (method !== 'initialize' && method !== 'notifications/initialized' && !sessionId) {
    await initializeMcp()
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
  }
  if (sessionId) headers['Mcp-Session-Id'] = sessionId

  const response = await fetch('/mcp', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      jsonrpc: '2.0',
      ...(method !== 'notifications/initialized' ? { id: Date.now() } : {}),
      method,
      ...(params ? { params } : {}),
    }),
  })
  const returnedSessionId = response.headers.get('Mcp-Session-Id')
  if (returnedSessionId) sessionId = returnedSessionId
  const text = await response.text()
  const body = parseMcpResponse(text)
  if (!response.ok || body?.error) throw new Error(body?.error?.message || `HTTP ${response.status}`)
  return body
}

async function initializeMcp(): Promise<void> {
  if (sessionSetup) return sessionSetup
  sessionSetup = (async () => {
    await mcp('initialize', {
      protocolVersion: '2025-06-18',
      capabilities: {},
      clientInfo: { name: 'dab-mcp-demo', version: '0.0.0' },
    })
    await mcp('notifications/initialized')
  })()
  try { await sessionSetup } catch (error) { sessionSetup = null; throw error }
}

export async function listTools(): Promise<McpTool[]> {
  const body = await mcp('tools/list')
  return body?.result?.tools || []
}

export async function callTool(name: string, args: Record<string, unknown>): Promise<unknown> {
  const body = await mcp('tools/call', { name, arguments: args })
  const result = body?.result
  if (result?.structuredContent) return result.structuredContent
  const text = result?.content?.find((item) => item.type === 'text')?.text
  if (!text) return result
  try {
    const payload = JSON.parse(text) as { result?: unknown }
    // DAB wraps DML payloads as { entity, result: { value: [...] } }.
    // Expose the inner result to the UI so grid/table renderers can consume it.
    return payload.result && typeof payload.result === 'object' ? payload.result : payload
  } catch { return text }
}

export async function health(): Promise<{ version?: string }> {
  const response = await fetch('/health')
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json() as Promise<{ version?: string }>
}
