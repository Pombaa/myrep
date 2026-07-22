# Sistema de Conversa com IA para Criação e Ajustes de Treino

## 📋 Visão Geral

Implementado um sistema completo de **conversa interativa com IA** para criar e ajustar planos de treino, com memória persistente de preferências do usuário.

---

## ✨ Principais Recursos

### 1. **Conversa Interativa com GPT-4**

- Interface de chat para refinar treinos em tempo real
- IA ajusta o plano conforme você conversa
- Histórico completo da conversa mantido
- Explicações em linguagem natural do que foi alterado

**Como usar:**
- Na tela "Plano de treino", clique em **"Conversar com IA para criar treino"**
- A IA gera um plano inicial baseado no seu perfil
- Você pode pedir ajustes: _"Quero menos exercícios para pernas"_, _"Adiciona mais cardio"_, etc.
- O treino é atualizado imediatamente com suas sugestões
- Ao finalizar, clique em ✓ para salvar

### 2. **Sistema de Lembretes Inteligentes**

Memória persistente de **restrições e preferências importantes**, que a IA **sempre considera** ao gerar novos treinos.

**Categorias de lembretes:**
- 🩹 **Lesão/Restrição:** _"Evitar agachamentos por lesão no joelho"_
- ❤️ **Preferência:** _"Prefiro treinos matinais"_, _"Não gosto de supino"_
- 🏋️ **Equipamento:** _"Só tenho acesso a halteres"_
- 📅 **Horário/Agenda:** _"Não posso treinar às quintas"_
- 🏷️ **Outro:** qualquer outra observação relevante

**Como funciona:**
1. Durante a conversa, se você mencionar algo importante (ex: _"tenho lesão no joelho"_)
2. A IA sugere automaticamente salvar como lembrete
3. Você pode aceitar ou recusar
4. Lembretes salvos aparecem nas futuras gerações de treino

**Gerenciamento:**
- Acesse: **Ajustes → Lembretes de treino**
- Ative/desative lembretes conforme necessário
- Adicione manualmente novos lembretes
- Exclua lembretes antigos

### 3. **Modelo GPT-4 Avançado**

Atualizado de `gpt-4o-mini` para **`gpt-4o`** na conversa interativa, oferecendo:
- Melhor compreensão contextual
- Ajustes mais precisos e naturais
- Capacidade de lembrar detalhes da conversa
- Sugestões inteligentes de lembretes

---

## 🛠️ Arquitetura Técnica

### Novos Modelos

**`WorkoutChatMessage`** - Mensagens da conversa
```dart
class WorkoutChatMessage {
  final WorkoutChatRole role; // user | assistant
  final String content;       // Texto exibido
  final DateTime sentAt;
  final String? rawContent;   // JSON bruto da IA
}
```

**`WorkoutPlanState`** - Estado da sessão conversacional
```dart
class WorkoutPlanState {
  final WorkoutPlan? plan;              // Plano sendo refinado
  final List<WorkoutChatMessage> conversation;
  final String? basePrompt;             // Contexto inicial
  final bool isProcessing;
}
```

**`WorkoutReminder`** - Lembretes salvos
```dart
class WorkoutReminder {
  final int? id;
  final int userId;
  final DateTime createdAt;
  final String content;    // Ex: "Evitar agachamentos"
  final String category;   // injury|preference|equipment|schedule|other
  final bool isActive;
}
```

### Novos Providers

**`conversationalWorkoutProvider`**
- `startConversation()` - Inicia sessão com GPT-4
- `sendMessage(userMessage)` - Envia ajuste e recebe plano atualizado
- `saveFinalPlan()` - Persiste plano finalizado
- `clearConversation()` - Limpa estado

**`reminderManagerProvider`**
- `saveReminder(content, category)` - Salva novo lembrete
- `toggleReminder(id, isActive)` - Ativa/desativa
- `deleteReminder(id)` - Exclui permanentemente

### Novas Telas

**`ConversationalWorkoutScreen`**
- Interface de chat moderna
- Prévia do plano atual em banner superior
- Detecção automática de sugestões de lembrete
- Salvamento do plano finalizado

**`RemindersScreen`**
- Lista todos os lembretes (ativos e inativos)
- Filtros por categoria
- Adição manual de lembretes
- Ativação/desativação/exclusão

### Banco de Dados

Nova tabela `workout_reminders`:
```sql
CREATE TABLE workout_reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY(user_id) REFERENCES user_profile(id)
);
```

### Integração OpenAI

**Schema JSON expandido:**
```json
{
  "mensagem": "Texto explicativo das alterações",
  "treino": [...],  // Array de dias
  "sugestao_lembrete": {  // Opcional
    "conteudo": "Evitar agachamentos por lesão",
    "categoria": "injury"
  }
}
```

**System Prompt atualizado:**
- Inclui automaticamente todos os lembretes ativos
- Instrui a IA a sugerir novos lembretes quando relevante
- Contexto completo do usuário (perfil, avaliações, histórico)

---

## 🔄 Fluxo de Uso

### Criação Conversacional de Treino

```
1. Usuário: "Conversar com IA para criar treino"
   ↓
2. IA: Gera plano inicial (considera perfil + lembretes salvos)
   ↓
3. Usuário: "Adiciona mais exercícios para bíceps"
   ↓
4. IA: Atualiza plano + explica alterações
   ↓
5. Usuário: "Evita agachamento, tenho lesão no joelho"
   ↓
6. IA: Ajusta treino + sugere salvar lembrete
   ↓
7. Dialog aparece: "Salvar como lembrete?"
   ↓
8. Usuário aceita → Lembrete salvo
   ↓
9. Usuário: Clica em ✓ para salvar plano final
   ↓
10. Plano salvo + conversa arquivada
```

### Próximo Treino Usando Lembretes

```
1. Usuário gera novo treino (método rápido ou conversacional)
   ↓
2. Sistema carrega automaticamente todos os lembretes ativos
   ↓
3. Prompt enviado à IA inclui:
   - Perfil do usuário
   - Histórico de avaliações
   - LEMBRETES: "Evitar agachamentos por lesão no joelho"
   ↓
4. IA cria treino respeitando as restrições salvas
```

---

## 🎯 Benefícios

✅ **Personalização Total:** Treinos se adaptam exatamente ao que você precisa  
✅ **Memória Persistente:** IA nunca esquece suas restrições/preferências  
✅ **Iteração Rápida:** Ajuste o treino em tempo real via chat  
✅ **Contexto Completo:** IA conhece todo seu histórico e evolução  
✅ **Sugestões Inteligentes:** Sistema identifica quando salvar novas restrições  

---

## 📝 Exemplo Real

**Conversa:**

> **Você:** Cria um treino para mim  
> **IA:** Criei um plano de 5 dias focado em hipertrofia. Segunda-feira inicia com peito e tríceps...  
> **Você:** Ótimo, mas tenho problema no ombro direito, evita exercícios de impacto  
> **IA:** Ajustei o treino removendo desenvolvimento militar e adicionando elevações laterais com carga leve. Recomendo salvar "Evitar exercícios de impacto para ombro direito" como lembrete permanente?  
> [Dialog aparece]  
> **Você:** [Clica em "Salvar lembrete"]  
> **Você:** Perfeito! Salva esse treino  
> **IA:** ✓ Plano salvo com sucesso  

**Resultado:**  
- Treino personalizado salvo
- Lembrete ativo: todos os futuros treinos evitarão impacto no ombro
- Histórico completo da conversa arquivado

---

## 🚀 Próximos Passos (Opcional)

- [ ] Export/import de lembretes
- [ ] Compartilhamento de lembretes entre dispositivos
- [ ] Histórico de conversas antigas
- [ ] Sugestões de lembretes baseadas em histórico de lesões
- [ ] Análise de padrões: "Você sempre pede menos agachamento"

---

## 📦 Arquivos Criados/Modificados

### Novos Arquivos
- `lib/models/workout_chat_message.dart`
- `lib/models/workout_plan_state.dart`
- `lib/models/workout_reminder.dart`
- `lib/repositories/reminder_repository.dart`
- `lib/providers/reminder_providers.dart`
- `lib/providers/conversational_workout_provider.dart`
- `lib/screens/workout/conversational_workout_screen.dart`
- `lib/screens/settings/reminders_screen.dart`

### Arquivos Modificados
- `lib/services/database_service.dart` - Tabela `workout_reminders`
- `lib/services/openai_service.dart` - Aceita lista de mensagens + schema expandido
- `lib/providers/repository_providers.dart` - Provider de lembretes
- `lib/providers/workout_providers.dart` - Atualizado para novo formato de mensagens
- `lib/core/utils/workout_prompt_builder.dart` - Já incluía suporte a preferências
- `lib/screens/workout/workout_plan_screen.dart` - Botão para iniciar conversa
- `lib/screens/settings/settings_screen.dart` - Link para tela de lembretes

---

## 🔧 Configuração

**Nenhuma configuração adicional necessária!**

O sistema já está integrado e funcionando. Apenas certifique-se de ter sua chave OpenAI configurada em **Ajustes**.

---

**Pronto para usar! 🎉**
