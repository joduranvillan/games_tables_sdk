// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Framing binario mínimo: 4 bytes de longitud (big-endian) + el payload.
//! TCP es un stream de bytes sin límites de mensaje, así que sin esto no
//! hay forma de saber dónde termina un `CommandEnvelope`/`EventEnvelope`
//! serializado y empieza el siguiente.

use std::io::{self, Read, Write};
use std::net::TcpStream;

/// Tamaño máximo permitido para una trama TCP (256 KiB) para prevenir ataques OOM DoS.
pub const MAX_TCP_FRAME_BYTES: usize = 256 * 1024;

pub fn write_frame(stream: &mut TcpStream, bytes: &[u8]) -> io::Result<()> {
    if bytes.len() > MAX_TCP_FRAME_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "frame size {} exceeds MAX_TCP_FRAME_BYTES ({MAX_TCP_FRAME_BYTES})",
                bytes.len()
            ),
        ));
    }
    let len = bytes.len() as u32;
    stream.write_all(&len.to_be_bytes())?;
    stream.write_all(bytes)?;
    stream.flush()
}

pub fn read_frame(stream: &mut TcpStream) -> io::Result<Vec<u8>> {
    let mut len_buf = [0u8; 4];
    stream.read_exact(&mut len_buf)?;
    let len = u32::from_be_bytes(len_buf) as usize;
    if len > MAX_TCP_FRAME_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("frame size {len} exceeds MAX_TCP_FRAME_BYTES ({MAX_TCP_FRAME_BYTES})"),
        ));
    }

    let mut buf = vec![0u8; len];
    stream.read_exact(&mut buf)?;
    Ok(buf)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::TcpListener;
    use std::thread;

    #[test]
    fn test_read_frame_rejects_oversized_frame_without_oom() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();

        let handle = thread::spawn(move || {
            let (mut server_stream, _) = listener.accept().unwrap();
            read_frame(&mut server_stream)
        });

        let mut client = TcpStream::connect(addr).unwrap();
        // Enviar cabecera maliciosa de 0xFFFF_FFFF (4 GiB)
        client.write_all(&u32::MAX.to_be_bytes()).unwrap();
        client.flush().unwrap();

        let res = handle.join().unwrap();
        assert!(res.is_err());
        assert_eq!(res.unwrap_err().kind(), io::ErrorKind::InvalidData);
    }
}
