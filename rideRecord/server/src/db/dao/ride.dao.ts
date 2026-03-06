import prisma from '../index';
import type { Ride, Segment, Prisma } from '@prisma/client';

/**
 * Ride Data Access Object
 */
export const RideDAO = {
  /**
   * Create a new ride
   */
  async create(data: Prisma.RideCreateInput): Promise<Ride> {
    return prisma.ride.create({ data });
  },

  /**
   * Create ride with user relation
   */
  async createWithUser(
    userId: string,
    data: Omit<Prisma.RideCreateInput, 'user'>
  ): Promise<Ride> {
    return prisma.ride.create({
      data: {
        ...data,
        user: { connect: { id: userId } },
      },
    });
  },

  /**
   * Find ride by ID
   */
  async findById(id: string): Promise<Ride | null> {
    return prisma.ride.findUnique({ where: { id } });
  },

  /**
   * Find ride with segments
   */
  async findByIdWithSegments(id: string) {
    return prisma.ride.findUnique({
      where: { id },
      include: { segments: true },
    });
  },

  /**
   * Find rides by user ID
   */
  async findByUserId(
    userId: string,
    options?: {
      skip?: number;
      take?: number;
      orderBy?: Prisma.RideOrderByWithRelationInput;
      status?: string;
      updatedAfter?: Date;
    }
  ): Promise<Ride[]> {
    const where: Prisma.RideWhereInput = { userId };
    if (options?.status) {
      where.status = options.status;
    }
    if (options?.updatedAfter) {
      where.updatedAt = { gt: options.updatedAfter };
    }

    return prisma.ride.findMany({
      where,
      skip: options?.skip,
      take: options?.take,
      orderBy: options?.orderBy ?? { startTime: 'desc' },
    });
  },

  /**
   * Update ride
   */
  async update(id: string, data: Prisma.RideUpdateInput): Promise<Ride> {
    return prisma.ride.update({ where: { id }, data });
  },

  /**
   * Delete ride
   */
  async delete(id: string): Promise<Ride> {
    return prisma.ride.delete({ where: { id } });
  },

  /**
   * Complete a ride
   */
  async complete(
    id: string,
    data: {
      endTime: Date;
      duration: number;
      movingTime: number;
      distance: number;
      avgSpeed: number;
      maxSpeed: number;
      avgHeartRate?: number;
      maxHeartRate?: number;
      calories: number;
      elevationGain: number;
      elevationLoss: number;
    }
  ): Promise<Ride> {
    return prisma.ride.update({
      where: { id },
      data: {
        ...data,
        status: 'completed',
        syncStatus: 'pending',
      },
    });
  },

  /**
   * Mark ride as synced
   */
  async markSynced(id: string): Promise<Ride> {
    return prisma.ride.update({
      where: { id },
      data: {
        syncStatus: 'synced',
        syncedAt: new Date(),
      },
    });
  },

  /**
   * Count rides by user
   */
  async countByUser(userId: string, status?: string): Promise<number> {
    const where: Prisma.RideWhereInput = { userId };
    if (status) {
      where.status = status;
    }
    return prisma.ride.count({ where });
  },

  /**
   * Get rides in date range
   */
  async findByDateRange(
    userId: string,
    startDate: Date,
    endDate: Date
  ): Promise<Ride[]> {
    return prisma.ride.findMany({
      where: {
        userId,
        startTime: {
          gte: startDate,
          lte: endDate,
        },
        status: 'completed',
      },
      orderBy: { startTime: 'asc' },
    });
  },

  /**
   * Get pending sync rides
   */
  async findPendingSync(limit: number = 100): Promise<Ride[]> {
    return prisma.ride.findMany({
      where: {
        syncStatus: 'pending',
        status: 'completed',
      },
      take: limit,
      orderBy: { updatedAt: 'asc' },
    });
  },

  /**
   * Get ride statistics for period
   */
  async getStatsByPeriod(
    userId: string,
    startDate: Date,
    endDate: Date
  ) {
    const rides = await prisma.ride.findMany({
      where: {
        userId,
        startTime: { gte: startDate, lte: endDate },
        status: 'completed',
      },
      select: {
        distance: true,
        duration: true,
        calories: true,
        elevationGain: true,
        avgSpeed: true,
        adventurePercent: true,
      },
    });

    return {
      rides: rides.length,
      distance: rides.reduce((sum, r) => sum + (r.distance || 0), 0),
      duration: rides.reduce((sum, r) => sum + (r.duration || 0), 0),
      calories: rides.reduce((sum, r) => sum + (r.calories || 0), 0),
      elevationGain: rides.reduce((sum, r) => sum + (r.elevationGain || 0), 0),
      avgSpeed: rides.length > 0
        ? rides.reduce((sum, r) => sum + (r.avgSpeed || 0), 0) / rides.length
        : 0,
      adventurePercent: rides.length > 0
        ? rides.reduce((sum, r) => sum + (r.adventurePercent || 0), 0) / rides.length
        : 0,
    };
  },

  /**
   * Add segment to ride
   */
  async addSegment(rideId: string, data: Prisma.SegmentCreateInput): Promise<Segment> {
    return prisma.segment.create({
      data: {
        ...data,
        ride: { connect: { id: rideId } },
      },
    });
  },

  /**
   * Get segments by ride
   */
  async getSegments(rideId: string): Promise<Segment[]> {
    return prisma.segment.findMany({
      where: { rideId },
      orderBy: { startIndex: 'asc' },
    });
  },

  /**
   * Get track points by ride ID
   */
  async getTrackPoints(rideId: string): Promise<any[]> {
    return prisma.trackPoint.findMany({
      where: { rideId },
      orderBy: { timestamp: 'asc' },
    });
  },

  /**
   * Insert track points
   */
  async insertTrackPoints(
    rideId: string,
    points: Array<{
      timestamp: Date;
      latitude: number;
      longitude: number;
      altitude?: number | null;
      speed?: number | null;
      heartRate?: number | null;
    }>
  ): Promise<number> {
    const data = points.map(point => ({
      rideId,
      timestamp: point.timestamp,
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude,
      speed: point.speed,
      heartRate: point.heartRate,
    }));

    const result = await prisma.trackPoint.createMany({
      data,
      skipDuplicates: true,
    });

    return result.count;
  },
};

export default RideDAO;
