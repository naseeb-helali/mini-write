jest.mock('../src/storage/providers/minio', () => ({
  getObject: jest.fn(),
  putObject: jest.fn()
}));

const storageProvider =
  require('../src/storage');

const storageService =
  require('../src/storage/storageService');

const minioProvider =
  require('../src/storage/providers/minio');

describe('Worker Storage Provider Boundary', () => {

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test(
    'Provider selector should resolve MinIO provider',
    () => {

      expect(
        storageProvider
      ).toBeDefined();

      expect(
        storageProvider.getObject
      ).toBeDefined();

      expect(
        storageProvider.putObject
      ).toBeDefined();
    }
  );

  test(
    'Storage service should expose configured buckets',
    () => {

      expect(
        storageService.INPUT_BUCKET
      ).toBe('uploads');

      expect(
        storageService.OUTPUT_BUCKET
      ).toBe('processed');
    }
  );


  test(
    'Storage service should delegate getObject',
    async () => {

      const stream = {};

      minioProvider.getObject
        .mockResolvedValue(stream);

      const result =
        await storageService.getObject(
          'uploads',
          'test.jpg'
        );

      expect(
        minioProvider.getObject
      ).toHaveBeenCalledWith(
        'uploads',
        'test.jpg'
      );

      expect(result).toBe(stream);
    }
  );

  test(
    'Storage service should delegate putObject',
    async () => {

      const buffer =
        Buffer.from('test');

      await storageService.putObject(
        'processed',
        'thumb.jpg',
        buffer,
        {
          'Content-Type':
            'image/jpeg'
        }
      );

      expect(
        minioProvider.putObject
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