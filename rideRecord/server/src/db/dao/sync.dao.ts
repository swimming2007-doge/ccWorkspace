import prisma from '../index';
import type { SyncRecord, Prisma } from '@prisma/client';

/**
 * Sync Record Data Access Object
 */
export const SyncDAO = {
  /**
   * Create a new sync record
   */
  async create(data: Prisma.SyncRecordCreateInput): Promise<SyncRecord> {
    return prisma.syncRecord.create({ data });
  },

  /**
   * Create sync record with user relation
   */
  async createWithUser(
    userId: string,
    data: Omit<Prisma.SyncRecordCreateInput, 'user'>
  ): Promise<SyncRecord> {
    return prisma.syncRecord.create({
      data: {
        ...data,
        user: { connect: { id: userId } },
      },
    });
  },

  /**
   * Find sync record by ID
   */
  async findById(id: string): Promise<SyncRecord | null> {
    return prisma.syncRecord.findUnique({ where: { id } });
  },

  /**
   * Find sync records by user
   */
  async findByUserId(
    userId: string,
    options?: { skip?: number; take?: number }
  ): Promise<SyncRecord[]> {
    return prisma.syncRecord.findMany({
      where: { userId },
      skip: options?.skip,
      take: options?.take ?? 50,
      orderBy: { createdAt: 'desc' },
    });
  },

  /**
   * Find pending sync records
   */
  async findPending(limit: number = 100): Promise<SyncRecord[]> {
    return prisma.syncRecord.findMany({
      where: { status: 'pending' },
      take: limit,
      orderBy: { createdAt: 'asc' },
    });
  },

  /**
   * Update sync record status
   */
  async updateStatus(
    id: string,
    status: string,
    errorMessage?: string
  ): Promise<SyncRecord> {
    return prisma.syncRecord.update({
      where: { id },
      data: {
        status,
        errorMessage,
        completedAt: status === 'success' ? new Date() : undefined,
      },
    });
  },

  /**
   * Mark as success
   */
  async markSuccess(id: string): Promise<SyncRecord> {
    return prisma.syncRecord.update({
      where: { id },
      data: {
        status: 'success',
        completedAt: new Date(),
      },
    });
  },

  /**
   * Mark as failed
   */
  async markFailed(id: string, errorMessage: string): Promise<SyncRecord> {
    return prisma.syncRecord.update({
      where: { id },
      data: {
        status: 'failed',
        errorMessage,
      },
    });
  },

  /**
   * Delete old sync records
   */
  async deleteOlderThan(days: number): Promise<number> {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - days);

    const result = await prisma.syncRecord.deleteMany({
      where: {
        createdAt: { lt: cutoff },
        status: { in: ['success', 'failed'] },
      },
    });

    return result.count;
  },

  /**
   * Get sync statistics
   */
  async getStats(userId: string) {
    const [total, pending, success, failed] = await Promise.all([
      prisma.syncRecord.count({ where: { userId } }),
      prisma.syncRecord.count({ where: { userId, status: 'pending' } }),
      prisma.syncRecord.count({ where: { userId, status: 'success' } }),
      prisma.syncRecord.count({ where: { userId, status: 'failed' } }),
    ]);

    return { total, pending, success, failed };
  },
};

export default SyncDAO;
