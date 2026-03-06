import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { ApiError } from '../middleware/error.middleware';
import { DeviceDAO } from '../db/dao';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const registerDeviceSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['phone', 'watch']),
  model: z.string().optional(),
  osVersion: z.string().optional(),
  appVersion: z.string().optional(),
});

// ===========================================
// Routes
// ===========================================

/**
 * @swagger
 * /devices:
 *   get:
 *     summary: Get list of registered devices
 *     tags: [Devices]
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const devices = await DeviceDAO.findByUserId(req.user!.id);

    res.json({
      devices: devices.map(d => ({
        id: d.id,
        name: d.name,
        type: d.type,
        model: d.model,
        osVersion: d.osVersion,
        appVersion: d.appVersion,
        lastSyncAt: d.lastSyncAt,
        status: d.status,
        createdAt: d.createdAt,
      })),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /devices/bind:
 *   post:
 *     summary: Register/bind a new device
 *     tags: [Devices]
 */
router.post('/bind', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = registerDeviceSchema.parse(req.body);

    const device = await DeviceDAO.findOrCreate(req.user!.id, data);

    res.status(201).json({
      message: 'Device registered successfully',
      device: {
        id: device.id,
        name: device.name,
        type: device.type,
        status: device.status,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /devices/{id}:
 *   get:
 *     summary: Get device by ID
 *     tags: [Devices]
 */
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const device = await DeviceDAO.findById(req.params.id);

    if (!device) {
      throw ApiError.notFound('Device not found');
    }

    if (device.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    res.json({ device });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /devices/{id}:
 *   delete:
 *     summary: Unbind/delete a device
 *     tags: [Devices]
 */
router.delete('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const device = await DeviceDAO.findById(req.params.id);

    if (!device) {
      throw ApiError.notFound('Device not found');
    }

    if (device.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    await DeviceDAO.delete(device.id);

    res.json({ message: 'Device unbound successfully' });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /devices/{id}/sync:
 *   post:
 *     summary: Trigger sync for a device
 *     tags: [Devices]
 */
router.post('/:id/sync', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const device = await DeviceDAO.findById(req.params.id);

    if (!device) {
      throw ApiError.notFound('Device not found');
    }

    if (device.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    // Update last sync time
    await DeviceDAO.updateLastSync(device.id);

    res.json({
      message: 'Sync triggered',
      deviceId: device.id,
      lastSyncAt: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});

export default router;
