const minioClient =
  require('minio').__mockMinioClient;

const minioProvider =
  require('../src/storage/providers/minio');

describe('Worker MinIO Storage Provider', () => {

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test(
    'should delegate getObject to MinIO client',
    async () => {

      const stream = {};

      minioClient.getObject
        .mockResolvedValue(stream);

      const result =
        await minioProvider.getObject(
          'uploads',
          'test.jpg'
        );

      expect(
        minioClient.getObject
      ).toHaveBeenCalledWith(
        'uploads',
        'test.jpg'
      );

      expect(result).toBe(stream);
    }
  );

  test(
    'should delegate putObject to MinIO client',
    async () => {

      const buffer =
        Buffer.from('test');

      await minioProvider.putObject(
        'processed',
        'thumb.jpg',
        buffer,
        {
          'Content-Type':
            'image/jpeg'
        }
      );

      expect(
        minioClient.putObject
      ).toHaveBeenCalledWith(
        'processed',
        'thumb.jpg',
        buffer,
        {
          'Content-Type':
            'image/jpeg'
        }
      );
    }
  );


});