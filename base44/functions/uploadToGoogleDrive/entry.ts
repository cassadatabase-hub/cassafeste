import { createClientFromRequest } from 'npm:@base44/sdk@0.8.40';

Deno.serve(async (req) => {
  try {
    const base44 = createClientFromRequest(req);
    const user = await base44.auth.me();
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });

    const body = await req.json();
    const { fileBase64, fileName, folderName } = body;

    if (!fileBase64 || !fileName) {
      return Response.json({ error: 'Missing file data or filename' }, { status: 400 });
    }

    const { accessToken } = await base44.asServiceRole.connectors.getConnection('googledrive');

    // Decode base64 to bytes
    const binaryString = atob(fileBase64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    // Find or create folder for the festa
    let folderId = null;
    if (folderName) {
      const searchUrl = `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(`name='${folderName}' and mimeType='application/vnd.google-apps.folder' and trashed=false`)}&fields=files(id,name)`;
      const searchResponse = await fetch(searchUrl, {
        headers: { 'Authorization': `Bearer ${accessToken}` },
      });
      if (searchResponse.ok) {
        const searchResult = await searchResponse.json();
        if (searchResult.files && searchResult.files.length > 0) {
          folderId = searchResult.files[0].id;
        }
      }
      if (!folderId) {
        const createFolderResponse = await fetch('https://www.googleapis.com/drive/v3/files', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            name: folderName,
            mimeType: 'application/vnd.google-apps.folder',
          }),
        });
        if (createFolderResponse.ok) {
          const folderResult = await createFolderResponse.json();
          folderId = folderResult.id;
        }
      }
    }

    // Multipart upload to Google Drive
    const boundary = '-------base44_' + Math.random().toString(36).substring(2);
    const mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    const metadata = JSON.stringify({
      name: fileName,
      mimeType,
      ...(folderId ? { parents: [folderId] } : {}),
    });

    const multipartHeader =
      `--${boundary}\r\n` +
      `Content-Type: application/json; charset=UTF-8\r\n\r\n` +
      `${metadata}\r\n` +
      `--${boundary}\r\n` +
      `Content-Type: ${mimeType}\r\n\r\n`;
    const multipartFooter = `\r\n--${boundary}--`;

    const headerBytes = new TextEncoder().encode(multipartHeader);
    const footerBytes = new TextEncoder().encode(multipartFooter);
    const fullBody = new Uint8Array(headerBytes.length + bytes.length + footerBytes.length);
    fullBody.set(headerBytes, 0);
    fullBody.set(bytes, headerBytes.length);
    fullBody.set(footerBytes, headerBytes.length + bytes.length);

    const response = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': `multipart/related; boundary=${boundary}`,
        },
        body: fullBody,
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      return Response.json({ error: 'Google Drive upload failed', details: errorText }, { status: 502 });
    }

    const result = await response.json();
    return Response.json({
      success: true,
      fileId: result.id,
      fileUrl: result.webViewLink || `https://drive.google.com/file/d/${result.id}/view`,
      folderId,
    });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
});