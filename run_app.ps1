# Iniciar Servidor del Chatbot en segundo plano
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npm start"

# Iniciar Flutter Web
flutter run -d chrome
