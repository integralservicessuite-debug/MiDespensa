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
exports.StoreService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let StoreService = class StoreService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async onModuleInit() {
        const count = await this.prisma.store.count();
        if (count === 0) {
            await this.prisma.store.create({
                data: {
                    name: 'Kissimmee Meat & Produce',
                    address: '1528 W. Vine St. Kissimmee, FL 34741',
                    phone: '407-350-5936',
                    email: 'info@kissimmeemeatproduce.com',
                    hours: 'Monday - Saturday 8:00 a.m. - 9:00 p. m.\nSunday 9:00 a. m. - 7:00 p. m.',
                    logoUrl: '/assets/logo.png'
                }
            });
            console.log('Store data seeded!');
        }
    }
    async getSettings() {
        return this.prisma.store.findFirst();
    }
};
exports.StoreService = StoreService;
exports.StoreService = StoreService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], StoreService);
//# sourceMappingURL=store.service.js.map