import os
import json
import http.client
import urllib.parse
import google.generativeai as genai

def lambda_handler(event, context):
    # Ler variáveis de ambiente
    VERIFY_TOKEN = os.environ.get("VERIFY_TOKEN")
    WHATSAPP_TOKEN = os.environ.get("WHATSAPP_TOKEN")
    
    # Só se quiser usar a Gemini:
    GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

    print("Event received:", json.dumps(event, indent=2))

    # Verifica se as variáveis básicas estão configuradas
    if not VERIFY_TOKEN or not WHATSAPP_TOKEN:
        print("Tokens não configurados nas variáveis de ambiente.")
        return {
            "statusCode": 500,
            "body": "Tokens não configurados."
        }

    # Definição inicial de response
    response = {}

    try:
        # Identifica método HTTP usado
        method = event.get("requestContext", {}).get("http", {}).get("method", "")

        if method == "GET":
            # Verificação do webhook
            print("Webhook verification request received.")
            query_params = event.get("queryStringParameters", {})

            if query_params:
                mode = query_params.get("hub.mode")
                if mode == "subscribe":
                    verify_token = query_params.get("hub.verify_token")
                    if verify_token == VERIFY_TOKEN:
                        # Retorna o desafio que o Facebook manda
                        challenge = query_params.get("hub.challenge")
                        response = {
                            "statusCode": 200,
                            "body": str(int(challenge)) if challenge else "No challenge",
                            "isBase64Encoded": False
                        }
                    else:
                        response = {
                            "statusCode": 403,
                            "body": "Error, wrong validation token",
                            "isBase64Encoded": False
                        }
                else:
                    response = {
                        "statusCode": 403,
                        "body": "Error, wrong mode",
                        "isBase64Encoded": False
                    }
            else:
                response = {
                    "statusCode": 403,
                    "body": "Error, no query parameters",
                    "isBase64Encoded": False
                }

        elif method == "POST":
            # Processamento de mensagens
            print("Message processing request received.")
            body_str = event.get("body", "{}")
            print("Message body:", body_str)

            body_json = json.loads(body_str)
            entries = body_json.get("entry", [])

            for entry in entries:
                changes = entry.get("changes", [])
                for change in changes:
                    value = change.get("value", {})
                    phone_number_id = value.get("metadata", {}).get("phone_number_id", "")
                    messages = value.get("messages", [])
                    
                    for msg in messages:
                        if msg.get("type") == "text":
                            from_number = msg.get("from")
                            user_text = msg["text"]["body"]
                            print("Usuário mandou a mensagem:", user_text)

                            # Chama a Gemini, se a chave estiver configurada
                            gemini_response_text = ""
                            if GEMINI_API_KEY:
                                gemini_response_text = call_gemini_api(user_text)
                                print("Resposta da Gemini:", gemini_response_text)
                            else:
                                gemini_response_text = "GEMINI_API_KEY não está configurada."

                            # Exemplo de mensagem de retorno
                            reply_message = f"Gemini disse: {gemini_response_text.strip()}"

                            # Enviar a resposta via WhatsApp
                            send_whatsapp_reply(
                                phone_number_id=phone_number_id,
                                whatsapp_token=WHATSAPP_TOKEN,
                                to=from_number,
                                reply_message=reply_message
                            )

                            response = {
                                "statusCode": 200,
                                "body": "Done",
                                "isBase64Encoded": False
                            }

        else:
            # Método não suportado
            response = {
                "statusCode": 403,
                "body": "Unsupported method",
                "isBase64Encoded": False
            }

    except Exception as e:
        print("Error processing request:", e)
        return {
            "statusCode": 500,
            "body": "Internal Server Error"
        }

    return response


def call_gemini_api(user_input):
    """
    Função que chama a Gemini API usando a biblioteca google.generativeai.
    Retorna a resposta do modelo (string).
    """
    try:
        # Configura o generative ai
        genai.configure(api_key=os.environ["GEMINI_API_KEY"])

        # Configurações de geração
        generation_config = {
            "temperature": 1,
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 8192,
            "response_mime_type": "text/plain",
        }

        # Define o modelo
        model = genai.GenerativeModel(
            model_name="gemini-2.0-flash-exp",
            generation_config=generation_config,
        )

        # Começa a sessão de chat
        chat_session = model.start_chat(
            history=[
                {
                    "role": "user",
                    "parts": ["oi tudo bem?\n"],
                },
                {
                    "role": "model",
                    "parts": ["Olá! Tudo bem por aqui, e com você? 😊\n"],
                },
            ]
        )

        # Envia a mensagem do usuário
        response = chat_session.send_message(user_input)

        return response.text

    except Exception as e:
        print("Erro ao chamar a Gemini API:", e)
        return "Erro ao chamar a Gemini API."


def send_whatsapp_reply(phone_number_id, whatsapp_token, to, reply_message):
    """
    Função que envia a resposta de volta via API do WhatsApp (graph.facebook.com).
    """
    payload = {
        "messaging_product": "whatsapp",
        "to": to,
        "text": {
            "body": reply_message
        }
    }
    data = json.dumps(payload)

    path = f"/v13.0/{phone_number_id}/messages"
    query = f"access_token={urllib.parse.quote(whatsapp_token)}"
    full_path = f"{path}?{query}"

    # Configura o cliente HTTP
    conn = http.client.HTTPSConnection("graph.facebook.com")
    headers = {
        "Content-Type": "application/json"
    }

    try:
        conn.request("POST", full_path, body=data, headers=headers)
        response = conn.getresponse()
        response_data = response.read().decode("utf-8")
        print("Resposta do WhatsApp API:", response_data)
    except Exception as e:
        print("Erro ao enviar resposta ao WhatsApp:", e)
    finally:
        conn.close()
