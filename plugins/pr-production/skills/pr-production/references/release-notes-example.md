# Reference: user-facing release notes

Format requested by the product owner (Cristhian Abrego, 2026-11-11). Every production release ships **two** versions:

1. The **technical list** (PR body, GitHub Release, staging update): keep sending it as today.
2. The **user version**: what the product owner publishes as-is. Rules are in `SKILL.md` › Step 7; this file is the worked example to imitate.

The example below is the product owner's own rewrite of one week's release. Copy its tone, length and structure, not its content.

---

## Novedades

### Un copiloto que configura tu agente contigo

Abre el asistente en el Brief y dile qué necesitas. Te propone el prompt, el conocimiento, los campos de contacto, los embudos, las automatizaciones y las herramientas, y te lleva a cada sección mientras te explica. También puedes hablarle con notas de voz.

**Dónde:** Agentes › Brief › botón del copiloto

[Captura: copiloto abierto proponiendo un plan por pasos]

### Embudos para ver en qué etapa está cada contacto

Un tablero por columnas donde el agente acomoda solo a cada contacto según la etapa en la que va. Cada agente usa su propio embudo.

**Dónde:** Agentes › Funnels

[Captura: tablero con contactos en varias etapas]

### Responde comentarios de Facebook e Instagram

El agente contesta los comentarios de tus publicaciones, en público o por mensaje privado. Tú eliges si responde a una palabra exacta o si decide él, y puedes poner un tope por hora para cuidar tu saldo.

**Dónde:** Agentes › Integrations › Triggers

[Captura: creación de un trigger de comentarios]

## Mejoras

- Agenda una sesión después del video de bienvenida, directo desde el onboarding.
- Prueba tus herramientas HTTP antes de guardarlas, con un botón en el formulario.
- Mensajes más claros:
  - al crear tu contraseña;
  - si no puedes crear una subcuenta o un agente, te dice por qué;
  - si falla un pago, ves el motivo real.
- Selector de idioma más compacto en el menú lateral.

## Arreglos

- La conexión de WhatsApp API ya no se interrumpe al terminar el registro.
- La página de Planes ya no falla si el navegador la traduce sola.
- La tarjeta que arrastras en el tablero de embudos ya no se corta.
- El botón de soporte ya no tapa el Inbox en el celular.

## Lo que quité de tu lista y por qué (interno, no publicar)

- Flags por agencia, hotfixes ya publicados y referencias a tickets: el usuario no los ve.
- El widget solo carga en sitios permitidos: es de seguridad y no cambia nada para el usuario. Si se quiere publicar, va como «Tu widget solo se muestra en los sitios que autorices».
- Subcuentas que se quedaban sin owner: es un arreglo interno.

---

## What the example teaches

- **Titles are benefits**, not feature names ("Responde comentarios de Facebook e Instagram", not "Comment triggers").
- **Big Novedades** get title + 1–3 sentences + `Dónde` + screenshot placeholder. Smaller Mejoras can be a one-line bullet; group related ones under a short lead line ("Mensajes más claros:").
- **Arreglos** say what no longer fails, in the user's words, one line each.
- **Disponible para** goes on any point that is not for everyone (flag-gated, plan-gated, AppSumo only, agencies only).
- **Lo que quité** always closes the document, with the reason for each removal, so the product owner can ask to put something back.
