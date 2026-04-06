# Exportacion de diagramas a PDF

## Opcion con Mermaid CLI
1. Instale Mermaid CLI:
   npm install -g @mermaid-js/mermaid-cli
2. Genere SVG:
   mmdc -i docs/diagramas/erd_postgresql.mmd -o docs/diagramas/erd_postgresql.svg
   mmdc -i docs/diagramas/erd_mysql.mmd -o docs/diagramas/erd_mysql.svg
3. Convierta SVG a PDF (ejemplo usando inkscape):
   inkscape docs/diagramas/erd_postgresql.svg --export-filename=docs/diagramas/erd_postgresql.pdf
   inkscape docs/diagramas/erd_mysql.svg --export-filename=docs/diagramas/erd_mysql.pdf

## Opcion desde VS Code
1. Abra el archivo `.mmd`.
2. Use una extension Mermaid para visualizar el diagrama.
3. Exporte o imprima a PDF.

## Entregable esperado
- docs/diagramas/erd_postgresql.pdf
- docs/diagramas/erd_mysql.pdf
