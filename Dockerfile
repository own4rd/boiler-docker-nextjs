# DEPS
FROM node:18-alpine AS base

#Install Dependencies
FROM base AS deps

# Compat...
RUN apk add --no-cache libc6-compat

WORKDIR /app

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# --------------- DEVELOPMENT ---------------

FROM base AS dev

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# -------------- BUILDER ---------------------
# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

COPY . .

# DISABLE METRICS
ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# ------------- RUNNER -----------------------
# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
CMD ["node", "server.js"]




# # EXPLICAÇÂO
# O uso do usuário "nextjs" no final do seu Dockerfile tem a finalidade de definir o usuário que será usado para executar o aplicativo dentro do contêiner quando ele estiver em execução. Essa prática é uma medida de segurança recomendada e uma boa prática ao criar imagens Docker para aplicativos.

# Aqui está a explicação da necessidade desse usuário:

# Princípio do Privilégio Mínimo (Least Privilege Principle): O princípio do privilégio mínimo é um conceito de segurança que sugere que um programa ou processo deve ter apenas as permissões e privilégios necessários para realizar sua tarefa. Ao definir um usuário específico (neste caso, "nextjs") para executar o aplicativo, você está restringindo as permissões do aplicativo apenas ao que é necessário para a sua execução. Isso ajuda a reduzir a superfície de ataque do sistema, tornando-o mais seguro.

# Isolamento de Processos: Definir um usuário separado para executar o aplicativo aumenta o isolamento entre o aplicativo e o restante do sistema dentro do contêiner. Se, por algum motivo, o aplicativo for comprometido ou explorado, ele terá acesso limitado ao sistema, uma vez que estará executando com as permissões do usuário "nextjs".

# Limitação de Impactos: Isolar o aplicativo em um usuário separado também limita o impacto de qualquer erro ou comportamento inesperado do aplicativo. Se o aplicativo tentar realizar ações não autorizadas ou prejudiciais, seu escopo de ação será restrito.

# Conformidade de Segurança: Em alguns ambientes regulamentados ou com requisitos de segurança mais rigorosos, é uma prática comum definir usuários específicos para cada aplicativo ou serviço para fins de auditoria e conformidade.