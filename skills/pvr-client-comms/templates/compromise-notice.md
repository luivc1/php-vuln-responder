# Compromise notice

Draft for the user to review carefully. If customer, payment or personal data may be
involved, recommend the client consult legal counsel about notification duties before
sending anything externally.

## EN
**Subject:** Important: security incident on {{site}}

Hi {{client_name}},

While responding to the critical PHP vulnerability {{CVES}}, we found signs that
{{site}} was accessed without authorization around {{first_seen}}.

What we found: {{findings_plain_language}}
What we did: {{containment_and_cleanup_done}} (evidence was preserved first).
Credentials we changed: {{rotated_credentials}}.
Still open: {{open_items_with_dates}}.

What we need from you: {{client_actions}}

We will update you by {{next_update_time}}.

{{your_name}}

## ES
**Asunto:** Importante: incidente de seguridad en {{site}}

Hola {{client_name}}:

Mientras atendíamos la vulnerabilidad crítica de PHP {{CVES}}, encontramos señales
de que {{site}} fue accedido sin autorización alrededor del {{first_seen}}.

Lo que encontramos: {{findings_plain_language}}
Lo que hicimos: {{containment_and_cleanup_done}} (preservamos la evidencia primero).
Credenciales que cambiamos: {{rotated_credentials}}.
Pendiente: {{open_items_with_dates}}.

Lo que necesitamos de usted: {{client_actions}}

Le actualizaremos antes de {{next_update_time}}.

{{your_name}}
