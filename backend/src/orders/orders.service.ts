
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LocationGateway } from '../location/location.gateway';

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private locationGateway: LocationGateway
  ) { }

  async create(data: any) {
    try {
      // 1. Verify customer exists or fallback to first CUSTOMER
      const existingUser = await this.prisma.user.findUnique({
        where: { id: data.customerId }
      });

      if (!existingUser) {
        console.warn(`User ${data.customerId} not found (probably old cache). Falling back to first customer.`);
        const fallbackClient = await this.prisma.user.findFirst({ where: { role: 'CUSTOMER' } });
        if (fallbackClient) data.customerId = fallbackClient.id;
      }

      // 2. Simulate Payment Intent
      if (data.paymentMethod === 'CARD') {
        console.log(`💳 [Stripe Simulator] Holding funds for Order...`);
        data.paymentStatus = 'AUTHORIZED';
        data.paymentIntentId = `pi_mock_${Math.random().toString(36).substring(7)}`;
      }

      // 3. Create Order
      const order = await this.prisma.order.create({ data });

      // 3. Sync User Profile (Address/Phone)
      if (data.deliveryAddress || data.contactPhone) {
        await this.prisma.user.update({
          where: { id: data.customerId },
          data: {
            address: data.deliveryAddress,
            phone: data.contactPhone,
            cardInfo: data.cardInfo
          }
        });
      }

      return order;
    } catch (e) {
      console.error('Failed to create order!', e);
      throw e;
    }
  }

  findAll() {
    return this.prisma.order.findMany({
      include: {
        items: { include: { product: true, replacementProduct: true } },
        customer: true
      },
    });
  }

  // Fetch orders available for shoppers (Status: CREATED)
  findForShoppers() {
    return this.prisma.order.findMany({
      where: { status: 'CREATED' },
      include: { items: { include: { product: true, replacementProduct: true } } },
    });
  }

  // Fetch orders ready for delivery (Status: DELIVERING or CHECKOUT)
  findForDrivers() {
    return this.prisma.order.findMany({
      where: { status: { in: ['CHECKOUT', 'DELIVERING'] } },
      include: { customer: true, delivery: true },
    });
  }

  // Fetch completed orders for driver history/earnings
  findCompletedForDrivers() {
    return this.prisma.order.findMany({
      where: { status: 'COMPLETED' },
      include: { customer: true, items: { include: { product: true } } },
      orderBy: { updatedAt: 'desc' }
    });
  }

  // --- BATCHING & LOGISTICS LOGIC ---
  async findAvailableBatches() {
    // Busca órdenes listas para recoger (Status: READY_FOR_PICKUP) o simuladas (CHECKOUT sin driver)
    const availableOrders = await this.prisma.order.findMany({
      where: {
        status: { in: ['READY_FOR_PICKUP', 'CHECKOUT'] },
        driverId: null
      },
      include: { customer: true, items: { include: { product: true } } },
      orderBy: { createdAt: 'asc' }
    });

    const batches: any[] = [];
    let currentBatch: any[] = [];

    for (const order of availableOrders) {
      currentBatch.push(order);
      if (currentBatch.length === 2) {
        batches.push({
          batchId: `BATCH-${currentBatch[0].id.substring(0, 6)}`,
          orders: currentBatch,
          estimatedEarnings: 3.00 * currentBatch.length // $3 base tarifa por orden
        });
        currentBatch = [];
      }
    }

    if (currentBatch.length > 0) {
      batches.push({
        batchId: `BATCH-${currentBatch[0].id.substring(0, 6)}`,
        orders: currentBatch,
        estimatedEarnings: 3.00 * currentBatch.length
      });
    }

    return batches;
  }

  async acceptBatch(driverId: string, orderIds: string[]) {
    const batchId = `BATCH-${orderIds[0].substring(0, 6)}`;

    // Validar el fallback driver
    let actualDriverId = driverId;
    if (!driverId) {
      const fd = await this.prisma.user.findFirst({ where: { role: 'DRIVER' } });
      if (fd) actualDriverId = fd.id;
    }

    await this.prisma.order.updateMany({
      where: { id: { in: orderIds } },
      data: {
        driverId: actualDriverId,
        batchId: batchId,
        status: 'DELIVERING'
      }
    });

    return { success: true, batchId: batchId, assignedOrders: orderIds.length };
  }

  findOne(id: string) {
    return this.prisma.order.findUnique({
      where: { id },
      include: { items: { include: { product: true, replacementProduct: true } } },
    });
  }

  async update(id: string, data: any) {
    if (data.status === 'COMPLETED') {
      const order = await this.prisma.order.findUnique({ where: { id } });
      if (order?.paymentMethod === 'CARD' && order?.paymentStatus === 'AUTHORIZED') {
        console.log(`💳 [Stripe Simulator] Capturing funds for Order ${id}...`);
        data.paymentStatus = 'CAPTURED';
      }
    }

    if (data.status === 'READY_FOR_PICKUP') {
      this.locationGateway.sendPushNotification(
        '¡Nuevas Órdenes Disponibles!',
        'Hay entregas listas para recoger en la tienda.',
        'DRIVERS'
      );
    }

    // Notifications for customer
    if (data.status === 'DELIVERING') {
      this.locationGateway.sendPushNotification(
        '¡Pedido en camino!',
        'Tu repartidor va de camino a tu domicilio.',
        'CUSTOMER'
      );
    }

    if (data.status === 'COMPLETED') {
      this.locationGateway.sendPushNotification(
        '¡Entrega finalizada!',
        'Tu pedido ha sido entregado. ¡Disfrútalo!',
        'CUSTOMER'
      );
    }

    return this.prisma.order.update({
      where: { id },
      data,
    });
  }

  updateItem(itemId: string, data: any) {
    return this.prisma.orderItem.update({
      where: { id: itemId },
      data,
    });
  }
}
