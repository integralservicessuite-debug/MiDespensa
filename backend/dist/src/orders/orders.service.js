"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let OrdersService = class OrdersService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(data) {
        try {
            const existingUser = await this.prisma.user.findUnique({
                where: { id: data.customerId }
            });
            if (!existingUser) {
                console.warn(`User ${data.customerId} not found (probably old cache). Falling back to first customer.`);
                const fallbackClient = await this.prisma.user.findFirst({ where: { role: 'CUSTOMER' } });
                if (fallbackClient)
                    data.customerId = fallbackClient.id;
            }
            const order = await this.prisma.order.create({ data });
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
        }
        catch (e) {
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
    findForShoppers() {
        return this.prisma.order.findMany({
            where: { status: 'CREATED' },
            include: { items: { include: { product: true, replacementProduct: true } } },
        });
    }
    findForDrivers() {
        return this.prisma.order.findMany({
            where: { status: { in: ['CHECKOUT', 'DELIVERING'] } },
            include: { customer: true, delivery: true },
        });
    }
    findCompletedForDrivers() {
        return this.prisma.order.findMany({
            where: { status: 'COMPLETED' },
            include: { customer: true, items: { include: { product: true } } },
            orderBy: { updatedAt: 'desc' }
        });
    }
    async findAvailableBatches() {
        const availableOrders = await this.prisma.order.findMany({
            where: {
                status: { in: ['READY_FOR_PICKUP', 'CHECKOUT'] },
                driverId: null
            },
            include: { customer: true, items: { include: { product: true } } },
            orderBy: { createdAt: 'asc' }
        });
        const batches = [];
        let currentBatch = [];
        for (const order of availableOrders) {
            currentBatch.push(order);
            if (currentBatch.length === 2) {
                batches.push({
                    batchId: `BATCH-${currentBatch[0].id.substring(0, 6)}`,
                    orders: currentBatch,
                    estimatedEarnings: 3.00 * currentBatch.length
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
    async acceptBatch(driverId, orderIds) {
        const batchId = `BATCH-${orderIds[0].substring(0, 6)}`;
        let actualDriverId = driverId;
        if (!driverId) {
            const fd = await this.prisma.user.findFirst({ where: { role: 'DRIVER' } });
            if (fd)
                actualDriverId = fd.id;
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
    findOne(id) {
        return this.prisma.order.findUnique({
            where: { id },
            include: { items: { include: { product: true, replacementProduct: true } } },
        });
    }
    update(id, data) {
        return this.prisma.order.update({
            where: { id },
            data,
        });
    }
    updateItem(itemId, data) {
        return this.prisma.orderItem.update({
            where: { id: itemId },
            data,
        });
    }
};
exports.OrdersService = OrdersService;
exports.OrdersService = OrdersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], OrdersService);
//# sourceMappingURL=orders.service.js.map