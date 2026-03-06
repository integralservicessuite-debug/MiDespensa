"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const bcrypt = __importStar(require("bcrypt"));
require("dotenv/config");
const prisma = new client_1.PrismaClient();
async function main() {
    const hashedPassword = await bcrypt.hash('123456', 10);
    const users = [
        { email: 'admin@market.com', role: 'ADMIN' },
        { email: 'shopper1@market.com', role: 'SHOPPER' },
        { email: 'driver1@market.com', role: 'DRIVER' },
        { email: 'client1@market.com', role: 'CUSTOMER' },
    ];
    for (const u of users) {
        await prisma.user.upsert({
            where: { email: u.email },
            update: {},
            create: {
                email: u.email,
                password: hashedPassword,
                role: u.role,
            },
        });
    }
    const client = await prisma.user.findUnique({ where: { email: 'client1@market.com' } });
    const categoriesData = [
        { name: 'Frutas y Verduras' },
        { name: 'Lácteos y Huevos' },
        { name: 'Panadería' },
        { name: 'Carnes' },
        { name: 'Despensa' }
    ];
    for (const c of categoriesData) {
        await prisma.category.upsert({
            where: { name: c.name },
            update: {},
            create: c
        });
    }
    const catFrutas = await prisma.category.findUnique({ where: { name: 'Frutas y Verduras' } });
    const catLacteos = await prisma.category.findUnique({ where: { name: 'Lácteos y Huevos' } });
    const catPan = await prisma.category.findUnique({ where: { name: 'Panadería' } });
    const catCarnes = await prisma.category.findUnique({ where: { name: 'Carnes' } });
    const catDespensa = await prisma.category.findUnique({ where: { name: 'Despensa' } });
    const productsData = [
        {
            name: 'Manzana Gala', price: 1.50, stockQuantity: 50, barcode: '1001',
            image: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6faa6?w=600&auto=format&fit=crop',
            categoryId: catFrutas?.id, aisle: '1', section: 'A', level: '2'
        },
        {
            name: 'Plátano Tabasco', price: 0.80, stockQuantity: 100, barcode: '1005',
            image: 'https://images.unsplash.com/photo-1571508601891-ca5e7a713859?w=600&auto=format&fit=crop',
            categoryId: catFrutas?.id, aisle: '1', section: 'B', level: '1'
        },
        {
            name: 'Tomate Saladette', price: 2.20, stockQuantity: 80, barcode: '1006',
            image: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop',
            categoryId: catFrutas?.id, aisle: '1', section: 'A', level: '1'
        },
        {
            name: 'Aguacate Hass', price: 3.50, stockQuantity: 40, barcode: '1007',
            image: 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=600&auto=format&fit=crop',
            categoryId: catFrutas?.id, aisle: '1', section: 'C', level: '2'
        },
        {
            name: 'Leche Entera 1L', price: 2.10, stockQuantity: 20, barcode: '1002',
            image: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&auto=format&fit=crop',
            categoryId: catLacteos?.id, aisle: '4', section: 'C', level: '1'
        },
        {
            name: 'Huevos 12u', price: 4.50, stockQuantity: 30, barcode: '1004',
            image: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=600&auto=format&fit=crop',
            categoryId: catLacteos?.id, aisle: '4', section: 'A', level: '3'
        },
        {
            name: 'Queso Fresco', price: 5.25, stockQuantity: 15, barcode: '1008',
            image: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=600&auto=format&fit=crop',
            categoryId: catLacteos?.id, aisle: '4', section: 'B', level: '2'
        },
        {
            name: 'Pan Integral', price: 3.00, stockQuantity: 25, barcode: '1003',
            image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop',
            categoryId: catPan?.id, aisle: '2', section: 'A', level: '2'
        },
        {
            name: 'Croissant x4', price: 4.50, stockQuantity: 12, barcode: '1009',
            image: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop',
            categoryId: catPan?.id, aisle: '2', section: 'B', level: '1'
        },
        {
            name: 'Carne Molida 500g', price: 6.50, stockQuantity: 40, barcode: '1010',
            image: 'https://images.unsplash.com/photo-1603048297172-c92544798d5e?w=600&auto=format&fit=crop',
            categoryId: catCarnes?.id, aisle: '5', section: 'A', level: '1'
        },
        {
            name: 'Pechuga de Pollo 1kg', price: 8.90, stockQuantity: 25, barcode: '1011',
            image: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=600&auto=format&fit=crop',
            categoryId: catCarnes?.id, aisle: '5', section: 'C', level: '2'
        },
        {
            name: 'Arroz Blanco 1kg', price: 1.80, stockQuantity: 100, barcode: '1012',
            image: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop',
            categoryId: catDespensa?.id, aisle: '3', section: 'A', level: '1'
        },
        {
            name: 'Aceite Vegetal 1L', price: 3.20, stockQuantity: 50, barcode: '1013',
            image: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&auto=format&fit=crop',
            categoryId: catDespensa?.id, aisle: '3', section: 'B', level: '2'
        },
        {
            name: 'Café Molido 250g', price: 7.50, stockQuantity: 35, barcode: '1014',
            image: 'https://images.unsplash.com/photo-1559525839-b184a4d698c7?w=600&auto=format&fit=crop',
            categoryId: catDespensa?.id, aisle: '3', section: 'C', level: '3'
        }
    ];
    for (const p of productsData) {
        await prisma.product.upsert({
            where: { barcode: p.barcode },
            update: {
                categoryId: p.categoryId,
                aisle: p.aisle,
                section: p.section,
                level: p.level
            },
            create: p,
        });
    }
    const apple = await prisma.product.findUnique({ where: { barcode: '1001' } });
    const milk = await prisma.product.findUnique({ where: { barcode: '1002' } });
    if (client && apple && milk) {
        await prisma.order.create({
            data: {
                customerId: client.id,
                status: 'CREATED',
                deliveryAddress: '123 Fake St, Orange County',
                contactPhone: '+1 555-0198',
                items: {
                    create: [
                        { productId: apple.id, quantityRequested: 5 },
                        { productId: milk.id, quantityRequested: 2 },
                    ]
                }
            }
        });
        await prisma.order.create({
            data: {
                customerId: client.id,
                status: 'DELIVERING',
                deliveryAddress: '456 Random Avenue, Apt 12',
                contactPhone: '+1 555-8910',
                items: {
                    create: [
                        { productId: apple.id, quantityRequested: 3 },
                    ]
                },
                delivery: {
                    create: {
                        driverId: (await prisma.user.findUnique({ where: { email: 'driver1@market.com' } })).id,
                    }
                }
            }
        });
    }
    console.log('Seed completed!');
}
main()
    .catch((e) => {
    console.error(e);
    process.exit(1);
})
    .finally(async () => {
    await prisma.$disconnect();
});
//# sourceMappingURL=seed.js.map