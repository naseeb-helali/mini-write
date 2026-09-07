const storageProvider =
  require('../src/storage');

const storageService =
  require('../src/services/storageService');

const minioClient =
  require('minio').__mockMinioClient;

describe('API Storage Provider Boundary', () => {

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('Provider selector should resolve MinIO provider', () => {

    expect(storageProvider).toBeDefined();

    expect(
      storageProvider.putObject
    ).toBeDefined();

    expect(
      storageProvider.getObject
    ).toBeDefined();
  });

  test(
    'Storage service should upload through the provider boundary',
    async () => {

      const file = {
        originalname: 'id-card.jpg',
        mimetype: 'image/jpeg',
        buffer: Buffer.from(
          'fake-image'
        )
      };

      const result =
        await storageService.uploadIdCard(
          file
        );

      expect(
        result.bucket
      ).toBe('user-documents');

      expect(
        result.fileName
      ).toMatch(/\.jpg$/);

      expect(
        minioClient.putObject
      ).toHaveBeenCalledWith(
        'user-documents',
        expect.stringMatching(
          /\.jpg$/
        ),
        file.buffer,
        {
          'Content-Type':
            'image/jpeg'
        }
      );
    }
  );

});