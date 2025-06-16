Rodar cloud function localmente:

1. Ativar o venv:
- Mac: `source venv/bin/activate`
2. Entrar na pasta da cloud function 
3. Exportar credenciais: `export GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json`
4. Subir a cloud function: `functions-framework --target=main --debug`
