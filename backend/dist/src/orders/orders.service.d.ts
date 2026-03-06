import { PrismaService } from '../prisma/prisma.service';
export declare class OrdersService {
    private prisma;
    constructor(prisma: PrismaService);
    create(data: any): Promise<{
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    }>;
    findAll(): import(".prisma/client").Prisma.PrismaPromise<({
        customer: {
            id: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            email: string;
            password: string;
            phone: string | null;
            role: string;
            address: string | null;
            cardInfo: string | null;
            currentLat: number | null;
            currentLng: number | null;
        };
        items: ({
            product: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            };
            replacementProduct: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            } | null;
        } & {
            id: string;
            status: string;
            quantityRequested: number;
            quantityFound: number | null;
            customerApprovedReplacement: boolean | null;
            productId: string;
            replacementProductId: string | null;
            orderId: string;
        })[];
    } & {
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    })[]>;
    findForShoppers(): import(".prisma/client").Prisma.PrismaPromise<({
        items: ({
            product: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            };
            replacementProduct: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            } | null;
        } & {
            id: string;
            status: string;
            quantityRequested: number;
            quantityFound: number | null;
            customerApprovedReplacement: boolean | null;
            productId: string;
            replacementProductId: string | null;
            orderId: string;
        })[];
    } & {
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    })[]>;
    findForDrivers(): import(".prisma/client").Prisma.PrismaPromise<({
        customer: {
            id: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            email: string;
            password: string;
            phone: string | null;
            role: string;
            address: string | null;
            cardInfo: string | null;
            currentLat: number | null;
            currentLng: number | null;
        };
        delivery: {
            id: string;
            driverId: string;
            pickupTime: Date | null;
            dropoffTime: Date | null;
            proofOfDeliveryImg: string | null;
            tipAmount: import("@prisma/client/runtime/library").Decimal | null;
            routePolyline: string | null;
            orderId: string;
        } | null;
    } & {
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    })[]>;
    findCompletedForDrivers(): import(".prisma/client").Prisma.PrismaPromise<({
        customer: {
            id: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            email: string;
            password: string;
            phone: string | null;
            role: string;
            address: string | null;
            cardInfo: string | null;
            currentLat: number | null;
            currentLng: number | null;
        };
        items: ({
            product: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            };
        } & {
            id: string;
            status: string;
            quantityRequested: number;
            quantityFound: number | null;
            customerApprovedReplacement: boolean | null;
            productId: string;
            replacementProductId: string | null;
            orderId: string;
        })[];
    } & {
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    })[]>;
    findAvailableBatches(): Promise<any[]>;
    acceptBatch(driverId: string, orderIds: string[]): Promise<{
        success: boolean;
        batchId: string;
        assignedOrders: number;
    }>;
    findOne(id: string): import(".prisma/client").Prisma.Prisma__OrderClient<({
        items: ({
            product: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            };
            replacementProduct: {
                id: string;
                createdAt: Date;
                updatedAt: Date;
                name: string;
                image: string | null;
                barcode: string | null;
                description: string | null;
                price: import("@prisma/client/runtime/library").Decimal;
                stockQuantity: number;
                aisle: string | null;
                section: string | null;
                level: string | null;
                allowSubstitutions: boolean;
                categoryId: string | null;
            } | null;
        } & {
            id: string;
            status: string;
            quantityRequested: number;
            quantityFound: number | null;
            customerApprovedReplacement: boolean | null;
            productId: string;
            replacementProductId: string | null;
            orderId: string;
        })[];
    } & {
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    }) | null, null, import("@prisma/client/runtime/library").DefaultArgs>;
    update(id: string, data: any): import(".prisma/client").Prisma.Prisma__OrderClient<{
        id: string;
        customerId: string;
        shopperId: string | null;
        driverId: string | null;
        batchId: string | null;
        status: string;
        deliveryWindowStart: Date | null;
        deliveryWindowEnd: Date | null;
        deliveryAddress: string | null;
        paymentMethod: string | null;
        contactPhone: string | null;
        deliveryFee: import("@prisma/client/runtime/library").Decimal | null;
        createdAt: Date;
        updatedAt: Date;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
    updateItem(itemId: string, data: any): import(".prisma/client").Prisma.Prisma__OrderItemClient<{
        id: string;
        status: string;
        quantityRequested: number;
        quantityFound: number | null;
        customerApprovedReplacement: boolean | null;
        productId: string;
        replacementProductId: string | null;
        orderId: string;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
}
