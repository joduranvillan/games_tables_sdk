use tokio_tungstenite::tungstenite::Message;

pub fn wrap_binary(data: &[u8]) -> Message {
    Message::Binary(data.to_vec().into())
}

pub fn extract_bytes(msg: &Message) -> Option<Vec<u8>> {
    match msg {
        Message::Binary(data) => Some(data.to_vec()),
        Message::Text(text) => Some(text.as_bytes().to_vec()),
        _ => None,
    }
}
