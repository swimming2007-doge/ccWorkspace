import prisma from '../index';
import type { User, Prisma } from '@prisma/client';

/**
 * User Data Access Object
 */
export const UserDAO = {
  /**
   * Create a new user
   */
  async create(data: Prisma.UserCreateInput): Promise<User> {
    return prisma.user.create({ data });
  },

  /**
   * Find user by ID
   */
  async findById(id: string): Promise<User | null> {
    return prisma.user.findUnique({ where: { id } });
  },

  /**
   * Find user by Huawei ID
   */
  async findByHuaweiId(huaweiId: string): Promise<User | null> {
    return prisma.user.findUnique({ where: { huaweiId } });
  },

  /**
   * Find user by email
   */
  async findByEmail(email: string): Promise<User | null> {
    return prisma.user.findUnique({ where: { email } });
  },

  /**
   * Update user
   */
  async update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return prisma.user.update({ where: { id }, data });
  },

  /**
   * Delete user
   */
  async delete(id: string): Promise<User> {
    return prisma.user.delete({ where: { id } });
  },

  /**
   * Update last login time
   */
  async updateLastLogin(id: string): Promise<User> {
    return prisma.user.update({
      where: { id },
      data: { lastLoginAt: new Date() },
    });
  },

  /**
   * Connect Strava account
   */
  async connectStrava(
    userId: string,
    accessToken: string,
    refreshToken: string,
    expiresAt: Date
  ): Promise<User> {
    return prisma.user.update({
      where: { id: userId },
      data: {
        stravaConnected: true,
        stravaAccessToken: accessToken,
        stravaRefreshToken: refreshToken,
        stravaTokenExpires: expiresAt,
      },
    });
  },

  /**
   * Disconnect Strava account
   */
  async disconnectStrava(userId: string): Promise<User> {
    return prisma.user.update({
      where: { id: userId },
      data: {
        stravaConnected: false,
        stravaAccessToken: null,
        stravaRefreshToken: null,
        stravaTokenExpires: null,
      },
    });
  },

  /**
   * Get user with devices
   */
  async findWithDevices(id: string) {
    return prisma.user.findUnique({
      where: { id },
      include: { devices: true },
    });
  },

  /**
   * Get user statistics
   */
  async getStats(userId: string) {
    const rides = await prisma.ride.aggregate({
      where: { userId, status: 'completed' },
      _count: true,
      _sum: {
        distance: true,
        duration: true,
        calories: true,
        elevationGain: true,
      },
      _avg: {
        avgSpeed: true,
      },
      _max: {
        distance: true,
        duration: true,
        maxSpeed: true,
      },
    });

    return {
      totalRides: rides._count,
      totalDistance: rides._sum.distance || 0,
      totalDuration: rides._sum.duration || 0,
      totalCalories: rides._sum.calories || 0,
      totalElevationGain: rides._sum.elevationGain || 0,
      avgSpeed: rides._avg.avgSpeed || 0,
      maxDistance: rides._max.distance || 0,
      maxDuration: rides._max.duration || 0,
      maxSpeed: rides._max.maxSpeed || 0,
    };
  },
};

export default UserDAO;
