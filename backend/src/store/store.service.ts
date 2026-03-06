
import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StoreService implements OnModuleInit {
  constructor(private prisma: PrismaService) { }

  async onModuleInit() {
    // Seed initial store data if not exists
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
}
