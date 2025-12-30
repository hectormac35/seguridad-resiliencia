route:
  receiver: telegram
  group_by: ["alertname"]
  group_wait: 10s
  group_interval: 30s
  repeat_interval: 2h

receivers:
  - name: telegram
    telegram_configs:
      - bot_token: "__BOT_TOKEN__"
        chat_id: __CHAT_ID__
        parse_mode: Markdown
        message: |
          *ALERTA:* {{ .CommonLabels.alertname }}
          *Severidad:* {{ .CommonLabels.severity }}
          *Resumen:* {{ .CommonAnnotations.summary }}
          *Detalle:* {{ .CommonAnnotations.description }}

          *Instancia:* {{ .CommonLabels.instance }}
