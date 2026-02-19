<div align="center">
<br>
<p>
  <img src="https://www.nok-chat.com.br/brand/nokk-icon.svg" height="80px"/>
</p>
<h1>Nokk Agents</h1>
<p>
  <strong>SDK Ruby para orquestração de agentes de IA multi-agente</strong>
</p>
<p>
  <a href="#instalação">Instalação</a> •
  <a href="#início-rápido">Início Rápido</a> •
  <a href="#arquitetura">Arquitetura</a> •
  <a href="#agentes">Agentes</a> •
  <a href="#ferramentas">Ferramentas</a> •
  <a href="#handoffs">Handoffs</a> •
  <a href="#observabilidade">Observabilidade</a>
</p>
<br>
</div>

O **Nokk Agents** é um framework Ruby para construir sistemas de IA com múltiplos agentes que colaboram entre si de forma transparente. Baseado no [ai-agents](https://github.com/chatwoot/ai-agents) da Chatwoot, estendido com customizações para o ecossistema Nokk.

Cada agente possui suas próprias instruções, ferramentas e relações de handoff. O sistema gerencia automaticamente a passagem de conversa entre agentes especializados — o usuário final nunca percebe a troca.

## Funcionalidades

- **Orquestração Multi-Agente** — Crie agentes especializados que trabalham em conjunto, cada um com seu papel definido
- **Handoffs Transparentes** — Transferências automáticas entre agentes sem que o usuário perceba
- **Ferramentas Customizáveis** — Agentes podem executar funções externas (APIs, bancos de dados, serviços)
- **Saída Estruturada** — Respostas validadas via JSON Schema para extração confiável de dados
- **Contexto Compartilhado** — Estado de conversa persistente entre trocas de agentes
- **Agnóstico de Provider** — Funciona com OpenAI, Anthropic, Gemini, DeepSeek, OpenRouter, Ollama e AWS Bedrock
- **Thread-Safe** — Projetado para uso concorrente em aplicações Rails multi-thread
- **Observabilidade** — Integração nativa com OpenTelemetry e Langfuse

---

## Instalação

Via GitHub:

```ruby
gem 'nokk-agents', github: 'nextlw/nokk-agents'
```

Ou via GitHub Packages (requer autenticação):

```ruby
source "https://rubygems.pkg.github.com/nextlw" do
  gem "nokk-agents", "~> 0.9.0"
end
```

---

## Início Rápido

### Configuração Básica

```ruby
require 'agents'

Agents.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_model = 'gpt-4.1-mini'
  config.request_timeout = 120
end
```

### Agente Simples

```ruby
agente = Agents::Agent.new(
  name: "Assistente",
  instructions: "Você é um assistente prestativo que responde em português.",
  tools: [BuscaCEPTool.new]
)

runner = Agents::Runner.with_agents(agente)
result = runner.run("Qual o CEP do centro de São Paulo?")
puts result.output
```

### Sistema Multi-Agente com Handoffs

```ruby
# Triagem — recebe todas as mensagens e direciona ao especialista
triagem = Agents::Agent.new(
  name: "Triagem",
  instructions: "Identifique a intenção do cliente e direcione ao agente correto."
)

# Agente de vendas
vendas = Agents::Agent.new(
  name: "Vendas",
  instructions: "Responda sobre planos, preços e faça a venda.",
  tools: [CatalogoTool.new, CriarPedidoTool.new]
)

# Agente de suporte
suporte = Agents::Agent.new(
  name: "Suporte",
  instructions: "Resolva problemas técnicos e de conta.",
  tools: [BuscarTicketTool.new, ConsultarFAQTool.new]
)

# Define as relações de handoff (quem pode transferir para quem)
triagem.register_handoffs(vendas, suporte)
vendas.register_handoffs(triagem)
suporte.register_handoffs(triagem)

# Cria o runner (reutilizável, thread-safe)
runner = Agents::Runner.with_agents(triagem, vendas, suporte)

# Executa — a triagem direciona automaticamente para vendas
result = runner.run("Quero saber os preços do plano premium")
puts result.output  # Resposta do agente de vendas

# Continua a conversa com contexto preservado
result = runner.run("Na verdade, estou com problema na minha conta",
                    context: result.context)
# Automaticamente transfere para suporte
```

---

## Arquitetura

### Componentes Principais

```
AgentRunner (registro de agentes + callbacks)
  │
  ▼
Runner.run() (motor de execução stateless)
  │
  ▼
RunContext (estado da execução + uso de tokens)
  │
  ▼
RubyLLM Chat (comunicação com o LLM)
  │
  ▼
ToolWrapper (injeção de contexto)
  │
  ▼
Tool.execute(ToolContext, **params)
```

| Componente | Responsabilidade |
|---|---|
| **Agent** | Definição imutável de um agente: instruções, modelo, ferramentas e relações de handoff |
| **AgentRunner** | Gerenciador thread-safe que coordena conversas multi-agente. Criado uma vez, reutilizado sempre |
| **Runner** | Orquestrador interno que executa turnos individuais de conversa |
| **RunContext** | Estado de execução isolado por conversa (contexto, uso de tokens, callbacks) |
| **ToolContext** | Acesso controlado ao estado durante execução de ferramentas |
| **Tool** | Funções externas que agentes podem executar |
| **Handoff** | Transferência automática entre agentes baseada em decisão do LLM |
| **CallbackManager** | Emissor de eventos thread-safe para observabilidade |

### Modelo de Thread Safety

O SDK foi projetado para ambientes multi-thread (como aplicações Rails com Puma):

1. **Agentes são imutáveis** — Configuração fixa, sem estado de execução
2. **Estado flui por parâmetros** — Nunca por variáveis de instância
3. **Cada execução é isolada** — `RunContext` e `ToolContext` independentes por conversa
4. **Ferramentas são stateless** — Mesma instância usada com segurança por múltiplas threads

---

## Agentes

### Criando um Agente

```ruby
agente = Agents::Agent.new(
  name: "Atendente",                          # Obrigatório
  instructions: "Você é um atendente...",      # String ou Proc
  model: "gpt-4.1-mini",                      # Modelo LLM (padrão: gpt-4.1-mini)
  tools: [MinhaTool.new],                      # Array de ferramentas
  temperature: 0.7,                            # Criatividade (0.0 a 1.0)
  response_schema: { type: "object", ... },    # JSON Schema para saída estruturada
  headers: { "X-Custom": "valor" }             # Headers HTTP customizados
)
```

### Instruções Dinâmicas

As instruções podem ser um `Proc` que recebe o contexto de execução, permitindo personalização por conversa:

```ruby
agente = Agents::Agent.new(
  name: "Atendente",
  instructions: ->(context) {
    cliente = context[:cliente_nome] || "cliente"
    "Você é o atendente do #{cliente}. Seja cordial e use o nome dele."
  }
)
```

### Clonando Agentes

Agentes são imutáveis. Para variações, use `clone`:

```ruby
agente_vip = agente.clone(
  name: "Atendente VIP",
  model: "gpt-4.1",
  instructions: "Tratamento premium para clientes VIP."
)
```

### Agente como Ferramenta

Um agente pode ser usado como ferramenta por outro agente. Diferente do handoff, o agente "chamado" executa uma tarefa isolada e retorna o resultado ao agente "chamador":

```ruby
pesquisador = Agents::Agent.new(
  name: "Pesquisador",
  instructions: "Pesquise informações detalhadas sobre o tema solicitado."
)

# Transforma o agente em ferramenta
pesquisa_tool = pesquisador.as_tool(
  name: "pesquisar_tema",
  description: "Pesquisa aprofundada sobre um tema"
)

# Outro agente usa como ferramenta
copiloto = Agents::Agent.new(
  name: "Copiloto",
  instructions: "Ajude o usuário utilizando pesquisa quando necessário.",
  tools: [pesquisa_tool]
)
```

O agente-ferramenta roda com contexto isolado (máximo 3 turnos) e **não pode fazer handoffs**.

---

## Ferramentas

### Criando uma Ferramenta

Ferramentas herdam de `Agents::Tool` e implementam o método `perform`:

```ruby
class BuscaCEPTool < Agents::Tool
  name "buscar_cep"
  description "Busca endereço completo a partir de um CEP"

  param :cep, type: "string", desc: "CEP no formato 00000-000"

  def perform(tool_context, cep:)
    # Acesse o contexto compartilhado
    api_key = tool_context.context[:viacep_key]

    # Faça a chamada externa
    response = HTTParty.get("https://viacep.com.br/ws/#{cep}/json/")

    # Retorne sempre uma String
    "Endereço: #{response['logradouro']}, #{response['bairro']} - #{response['localidade']}/#{response['uf']}"
  end
end
```

### Regras Importantes para Ferramentas

1. **Sempre retorne String** — O resultado é enviado de volta ao LLM
2. **Nunca armazene estado em variáveis de instância** — Use `tool_context` para tudo
3. **Todo estado vem por parâmetros** — Isso garante thread safety

### Acessando Estado Compartilhado

```ruby
def perform(tool_context, customer_id:)
  # Ler do contexto
  conta = tool_context.context[:account_id]

  # Compartilhar estado entre ferramentas/agentes
  tool_context.state[:ultimo_cliente] = customer_id

  # Rastrear uso de tokens de sub-chamadas LLM
  tool_context.usage.add(minha_resposta_llm.usage)

  "Cliente #{customer_id} encontrado"
end
```

---

## Handoffs

Handoffs são a transferência transparente de conversa entre agentes. O LLM decide quando transferir — o usuário nunca percebe.

### Como Funciona

1. O agente A é configurado com `register_handoffs(agente_b, agente_c)`
2. Ferramentas de handoff são criadas automaticamente (`handoff_to_agente_b`, `handoff_to_agente_c`)
3. O LLM decide chamar a ferramenta de handoff quando apropriado
4. O Runner detecta e troca para o novo agente
5. O histórico de conversa é preservado

### Padrões Comuns

**Hub-and-spoke** (triagem central):
```ruby
triagem.register_handoffs(vendas, suporte, financeiro)
vendas.register_handoffs(triagem)
suporte.register_handoffs(triagem)
financeiro.register_handoffs(triagem)
```

**Circular** (especialistas se transferem entre si):
```ruby
vendas.register_handoffs(suporte, financeiro)
suporte.register_handoffs(vendas, financeiro)
financeiro.register_handoffs(vendas, suporte)
```

---

## Callbacks

O `AgentRunner` emite eventos durante a execução. Útil para logs, métricas, atualizações em tempo real e debugging:

```ruby
runner = Agents::Runner.with_agents(triagem, vendas, suporte)

# Antes da execução começar
runner.on_run_start do |agent, input, context|
  Rails.logger.info "[Agents] Início: #{agent} recebeu: #{input}"
end

# Quando um agente está "pensando" (antes da chamada LLM)
runner.on_agent_thinking do |agent_name, input, context|
  ActionCable.server.broadcast("chat_#{context.context[:chat_id]}", { typing: agent_name })
end

# Quando ocorre uma transferência
runner.on_agent_handoff do |from, to, reason, context|
  Rails.logger.info "[Agents] Handoff: #{from} → #{to} (#{reason})"
end

# Quando uma ferramenta é executada
runner.on_tool_start do |tool_name, args, context|
  Rails.logger.debug "[Agents] Tool: #{tool_name}(#{args})"
end

runner.on_tool_complete do |tool_name, result, context|
  Rails.logger.debug "[Agents] Tool result: #{tool_name} → #{result[0..100]}"
end

# Quando a execução termina
runner.on_run_complete do |agent, result, context|
  Rails.logger.info "[Agents] Fim: #{agent} respondeu em #{context.usage.total_tokens} tokens"
end

# Após chamada LLM (útil para métricas)
runner.on_llm_call_complete do |agent_name, model, response, context|
  StatsD.increment("llm.calls", tags: ["agent:#{agent_name}", "model:#{model}"])
end
```

Todos os callbacks são **thread-safe** e **tolerantes a falhas** — erros em callbacks são logados mas nunca interrompem a execução.

---

## Contexto e Persistência

O contexto é um Hash que persiste entre interações e é totalmente serializável:

```ruby
# Primeira interação
result = runner.run("Olá, meu nome é Maria", context: {
  account_id: 42,
  chat_id: "abc-123"
})

# Serializar para banco de dados
json = JSON.dump(result.context)
# Salvar json no Redis, PostgreSQL, etc.

# Restaurar em outra request
contexto_restaurado = JSON.parse(json, symbolize_names: true)
result = runner.run("Qual o status do meu pedido?", context: contexto_restaurado)
# O sistema sabe qual agente estava ativo e restaura o histórico
```

O contexto armazena automaticamente:
- `conversation_history` — Mensagens da conversa
- `current_agent` — Nome do agente ativo (String, não objeto)
- `state` — Estado compartilhado entre ferramentas

---

## Saída Estruturada

Force o agente a responder em formato JSON validado:

```ruby
agente_extrator = Agents::Agent.new(
  name: "Extrator",
  instructions: "Extraia as informações do pedido a partir da mensagem do cliente.",
  response_schema: {
    type: "object",
    properties: {
      produto: { type: "string" },
      quantidade: { type: "integer" },
      endereco: { type: "string" }
    },
    required: ["produto", "quantidade"]
  }
)

result = runner.run("Quero 3 camisetas entregues na Rua A, 123")
dados = JSON.parse(result.output)
# => { "produto" => "camiseta", "quantidade" => 3, "endereco" => "Rua A, 123" }
```

---

## Resultado da Execução

O `runner.run()` retorna um `RunResult` com:

```ruby
result = runner.run("Olá")

result.output    # String — resposta do agente
result.messages  # Array<Hash> — histórico de mensagens formatado
result.usage     # Usage — { input_tokens, output_tokens, total_tokens }
result.context   # Hash — contexto atualizado (para persistência)
result.error     # Exception | nil — erro se houve falha

result.success?  # true se não houve erro e há output
result.failed?   # true se houve erro
```

---

## Configuração Completa

```ruby
Agents.configure do |config|
  # === Providers ===
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_api_base = "https://api.openai.com/v1"     # Ou endpoint compatível
  config.openai_organization_id = ENV['OPENAI_ORG_ID']
  config.openai_project_id = ENV['OPENAI_PROJECT_ID']

  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.ollama_api_base = "http://localhost:11434"

  # AWS Bedrock
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_region = "us-east-1"
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']

  # === Padrões ===
  config.default_model = "gpt-4.1-mini"
  config.request_timeout = 120    # segundos

  # === Debug ===
  config.debug = false
end
```

---

## Observabilidade

Integração opcional com OpenTelemetry para rastreamento de execução. Compatível com [Langfuse](https://langfuse.com) e outros backends OTel.

```ruby
require 'agents/instrumentation'

tracer = OpenTelemetry.tracer_provider.tracer('nokk-agents')
runner = Agents::Runner.with_agents(triagem, vendas, suporte)

Agents::Instrumentation.install(runner,
  tracer: tracer,
  trace_name: "nokk.agents.run",
  span_attributes: { "app.name" => "nokk-omni" },
  attribute_provider: ->(ctx) {
    { "session.id" => ctx.context[:chat_id] }
  }
)
```

### Hierarquia de Spans

```
nokk.agents.run
├── agent.Triagem
│   ├── .generation          ← chamada LLM (modelo + tokens)
│   └── .handoff             ← evento de transferência
├── agent.Vendas
│   ├── .generation
│   └── .tool.buscar_produto ← execução de ferramenta
└── (run complete)
```

### Integração com Langfuse

Para agrupar spans por sessão, passe `session_id` no contexto:

```ruby
result = runner.run("Oi", context: { session_id: "chat-abc-123" })
```

---

## Versionamento

Este projeto segue [Semantic Versioning](https://semver.org/lang/pt-BR/). As versões são publicadas como GitHub Packages no repositório [nextlw/chat-bot](https://github.com/orgs/nextlw/packages?repo_name=chat-bot).

Para publicar uma nova versão:
1. Atualize `lib/agents/version.rb`
2. Faça push para `main`
3. Dispare o workflow "Publish nokk-agents" via GitHub Actions com a versão desejada

---

## Licença

Distribuído sob a licença MIT. Baseado no [ai-agents](https://github.com/chatwoot/ai-agents) da Chatwoot Inc.
