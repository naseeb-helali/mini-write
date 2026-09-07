jest.mock('../src/storage/storageService', () => ({
  getObject: jest.fn(),
  putObject: jest.fn(),

  INPUT_BUCKET: 'uploads',
  OUTPUT_BUCKET: 'processed'
}));

const { processIdCard } =
  require('../src/processors/imageProcessor');

const pool =
  require('../src/config/db');

const storageService =
  require('../src/storage/storageService');

const { Readable } =
  require('stream');

describe('Image Processor - Unit Tests', () => {

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('Success: Process image, upload to storage, and update DB', async () => {

    const mockJob = {
      data: {
        fileName: 'user123_id.jpg',
        userId: 1
      }
    };

    const mockClient = {
      query: jest.fn()
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({
          rows: [
            {
              identity_status: 'pending'
            }
          ]
        })
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [
            {
              id: 1
            }
          ]
        })
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({
          rowCount: 1
        })
        .mockResolvedValueOnce({}),

      release: jest.fn()
    };

    pool.connect.mockResolvedValue(
      mockClient
    );

    const mockStream =
      new Readable();

    mockStream.push(
      'fake-image-binary-data'
    );

    mockStream.push(null);

    storageService.getObject
      .mockResolvedValue(
        mockStream
      );

    storageService.putObject
      .mockResolvedValue({
        etag: 'processed-etag'
      });

    const result =
      await processIdCard(mockJob);

    expect(result).toEqual({
      success: true,
      userId: 1,
      file: 'thumb_user123_id.jpg'
    });

    expect(
      mockClient.query
    ).toHaveBeenCalledWith(
      expect.stringContaining(
        'BEGIN'
      )
    );

    expect(
      mockClient.query
    ).toHaveBeenCalledWith(
      expect.stringContaining(
        "identity_status = 'verified'"
      ),
      expect.arrayContaining([
        'thumb_user123_id.jpg',
        1
      ])
    );

    expect(
      storageService.getObject
    ).toHaveBeenCalledWith(
      storageService.INPUT_BUCKET,
      'user123_id.jpg'
    );

    expect(
      storageService.putObject
    ).toHaveBeenCalledWith(
      storageService.OUTPUT_BUCKET,
      'thumb_user123_id.jpg',
      expect.any(Buffer),
      {
        'Content-Type': 'image/jpeg'
      }
    );
  });

  test(
    'Skipped: Should skip if identity_status is already processing or verified',
    async () => {

      const mockJob = {
        data: {
          fileName: 'test.jpg',
          userId: 1
        }
      };

      const mockClient = {
        query: jest.fn()
          .mockResolvedValueOnce({})
          .mockResolvedValueOnce({
            rows: [
              {
                identity_status:
                  'processing'
              }
            ]
          }),

        release: jest.fn()
      };

      pool.connect.mockResolvedValue(
        mockClient
      );

      const result =
        await processIdCard(
          mockJob
        );

      expect(result).toEqual({
        skipped: true
      });

      expect(
        storageService.getObject
      ).not.toHaveBeenCalled();

      expect(
        storageService.putObject
      ).not.toHaveBeenCalled();

      expect(
        mockClient.release
      ).toHaveBeenCalled();
    }
  );

  test(
    'Failure: Should throw error if file exceeds 5MB limit',
    async () => {

      const mockJob = {
        data: {
          fileName: 'huge_file.jpg',
          userId: 1
        }
      };

      const mockClient = {
        query: jest.fn()
          .mockResolvedValueOnce({})
          .mockResolvedValueOnce({
            rows: [
              {
                identity_status:
                  'pending'
              }
            ]
          })
          .mockResolvedValueOnce({
            rowCount: 1,
            rows: [
              {
                id: 1
              }
            ]
          })
          .mockResolvedValueOnce({}),

        release: jest.fn()
      };

      pool.connect.mockResolvedValue(
        mockClient
      );

      const hugeStream =
        new Readable();

      hugeStream.push(
        Buffer.alloc(
          6 * 1024 * 1024
        )
      );

      hugeStream.push(null);

      storageService.getObject
        .mockResolvedValue(
          hugeStream
        );

      await expect(
        processIdCard(mockJob)
      ).rejects.toThrow(
        'File too large - potential memory risk'
      );
    }
  );
});