# Hosting provider ticket

## EN
**Subject:** Urgent: PHP {{CVES}} ({{ADVISORY_NAME}}) on account {{account_or_domain}}

Hello,

Regarding the critical PHP vulnerabilities {{CVES}} (fixed upstream in
{{FIXED_VERSIONS}}), please confirm for {{domains}}:

1. The exact PHP build currently serving these domains (SAPI and version).
2. Whether that build includes the fix for {{CVES}} (upstream release or backport).
3. If not, when the fix will be deployed, and whether we can switch these domains
   now to a version that includes it.
4. Whether PHP-FPM/LSAPI processes were restarted after the update.

The domains currently report: {{scan_result_summary}}.

Thank you,
{{your_name}} / {{company}}

## ES
**Asunto:** Urgente: PHP {{CVES}} ({{ADVISORY_NAME}}) en la cuenta {{account_or_domain}}

Hola:

Con relación a las vulnerabilidades críticas de PHP {{CVES}} (corregidas en
{{FIXED_VERSIONS}}), favor de confirmar para {{domains}}:

1. La versión exacta de PHP que sirve actualmente estos dominios (SAPI y versión).
2. Si esa versión incluye la corrección de {{CVES}} (versión oficial o backport).
3. Si no la incluye, cuándo se aplicará y si podemos cambiar ya estos dominios a una
   versión que la incluya.
4. Si los procesos PHP-FPM/LSAPI se reiniciaron después de la actualización.

Los dominios reportan actualmente: {{scan_result_summary}}.

Gracias,
{{your_name}} / {{company}}
