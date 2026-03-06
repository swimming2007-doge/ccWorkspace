import prisma from '../index';
import type { Device, Prisma } from '@prisma/client';

/**
 * Device Data Access Object
 */
export const DeviceDAO = {
  /**
   * Create a new device
   */
  async create(data: Prisma.DeviceCreateInput): Promise<Device> {
    return prisma.device.create({ data });
  },

  /**
   * Create device with user relation
   */
  async createWithUser(
    userId: string,
    data: Omit<Prisma.DeviceCreateInput, 'user'>
  ): Promise<Device> {
    return prisma.device.create({
      data: {
        ...data,
        user: { connect: { id: userId } },
      },
    });
  },

  /**
   * Find device by ID
   */
  async findById(id: string): Promise<Device | null> {
    return prisma.device.findUnique({ where: { id } });
  },

  /**
   * Find devices by user ID
   */
  async findByUserId(userId: string): Promise<Device[]> {
    return prisma.device.findMany({
      where: { userId },
      orderBy: { lastSyncAt: 'desc' },
    });
  },

  /**
   * Find active devices by user
   */
  async findActiveByUser(userId: string): Promise<Device[]> {
    return prisma.device.findMany({
      where: { userId, status: 'active' },
      orderBy: { lastSyncAt: 'desc' },
    });
  },

  /**
   * Update device
   */
  async update(id: string, data: Prisma.DeviceUpdateInput): Promise<Device> {
    return prisma.device.update({ where: { id }, data });
  },

  /**
   * Update last sync time
   */
  async updateLastSync(id: string): Promise<Device> {
    return prisma.device.update({
      where: { id },
      data: { lastSyncAt: new Date() },
    });
  },

  /**
   * Deactivate device
   */
  async deactivate(id: string): Promise<Device> {
    return prisma.device.update({
      where: { id },
      data: { status: 'inactive' },
    });
  },

  /**
   * Delete device
   */
  async delete(id: string): Promise<Device> {
    return prisma.device.delete({ where: { id } });
  },

  /**
   * Count devices by user
   */
  async countByUser(userId: string): Promise<number> {
    return prisma.device.count({ where: { userId } });
  },

  /**
   * Find or create device
   */
  async findOrCreate(
    userId: string,
    deviceData: {
      name: string;
      type: string;
      model?: string;
      osVersion?: string;
      appVersion?: string;
    }
  ): Promise<Device> {
    // Try to find existing device with same name and type
    const existing = await prisma.device.findFirst({
      where: {
        userId,
        name: deviceData.name,
        type: deviceData.type,
      },
    });

    if (existing) {
      // Update device info
      return prisma.device.update({
        where: { id: existing.id },
        data: {
          ...deviceData,
          status: 'active',
          lastSyncAt: new Date(),
        },
      });
    }

    // Create new device
    return prisma.device.create({
      data: {
        ...deviceData,
        user: { connect: { id: userId } },
        lastSyncAt: new Date(),
      },
    });
  },
};

export default DeviceDAO;
