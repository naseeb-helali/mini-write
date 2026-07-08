function classifyFileType(mimeType = '') {
  if (mimeType.startsWith('image/')) {
    return 'image';
  }

  if (
    mimeType.includes('pdf') ||
    mimeType.includes('word') ||
    mimeType.includes('text')
  ) {
    return 'document';
  }

  return 'other';
}

module.exports = classifyFileType;