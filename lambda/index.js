// index.js
const https = require("https");

exports.handler = async (event)  => {
  const VERIFY_TOKEN = "blue_panda";
  const WHATSAPP_TOKEN = "SEU_WHATSAPP_TOKEN_AQUI";

  let response;
  if (event?.requestContext?.http?.method === "GET") {
    let queryParams = event?.queryStringParameters;
    if (queryParams != null) {
      const mode = queryParams["hub.mode"];
      if (mode == "subscribe") {
        const verifyToken = queryParams["hub.verify_token"];
        if (verifyToken == VERIFY_TOKEN) {
          let challenge = queryParams["hub.challenge"];
          response = {
            statusCode: 200,
            body: parseInt(challenge),
            isBase64Encoded: false
          };
        } else {
          const responseBody = "Error, wrong validation token";
          response = {
            statusCode: 403,
            body: JSON.stringify(responseBody),
            isBase64Encoded: false
          };
        }
      } else {
        const responseBody = "Error, wrong mode";
        response = {
          statusCode: 403,
          body: JSON.stringify(responseBody),
          isBase64Encoded: false
        };
      }
    } else {
      const responseBody = "Error, no query parameters";
      response = {
        statusCode: 403,
        body: JSON.stringify(responseBody),
        isBase64Encoded: false
      };
    }
  } else if (event?.requestContext?.http?.method === "POST") {
    let body = JSON.parse(event.body);
    let entries = body.entry;
    for (let entry of entries) {
      for (let change of entry.changes) {
        let value = change.value;
        if (value != null) {
          let phone_number_id = value.metadata.phone_number_id;
          if (value.messages != null) {
            for (let message of value.messages) {
              if (message.type === 'text') {
                let from = message.from;
                let message_body = message.text.body;
                let reply_message = "Ack from AWS lambda: " + message_body;
                sendReply(phone_number_id, WHATSAPP_TOKEN, from, reply_message);

                const responseBody = "Done";
                response = {
                  statusCode: 200,
                  body: JSON.stringify(responseBody),
                  isBase64Encoded: false
                };
              }
            }
          }
        }
      }
    }
  } else {
    const responseBody = "Unsupported method";
    response = {
      statusCode: 403,
      body: JSON.stringify(responseBody),
      isBase64Encoded: false
    };
  }
  return response;
};

const sendReply = (phone_number_id, whatsapp_token, to, reply_message) => {
  let json = {
    messaging_product: "whatsapp",
    to: to,
    text: { body: reply_message },
  };
  let data = JSON.stringify(json);
  let path = "/v13.0/" + phone_number_id + "/messages?access_token=" + whatsapp_token;

  let options = {
    host: "graph.facebook.com",
    path: path,
    method: "POST",
    headers: { "Content-Type": "application/json" }
  };

  let callback = (response) => {
    let str = "";
    response.on("data", (chunk) => {
      str += chunk;
    });
    response.on("end", () => {
      // console.log("Resposta do WhatsApp API: ", str);
    });
  };
  let req = https.request(options, callback);
  req.on("error", (e) => {
    console.error(e);
  });
  req.write(data);
  req.end();
};
