
import { Injectable } from '@nestjs/common';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProductsService {
  private readonly BUFFER_QUANTITY = 2; // Regla: Buffer de Inventario

  constructor(private prisma: PrismaService) { }

  async create(createProductDto: CreateProductDto) {
    return this.prisma.product.create({
      data: createProductDto,
    });
  }

  async findAll() {
    const products = await this.prisma.product.findMany({
      include: { category: true },
    });
    return products.map(p => ({
      ...p,
      displayedStock: this.getDisplayedStock(p.stockQuantity),
    }));
  }

  async findOne(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) return null;
    return {
      ...product,
      displayedStock: this.getDisplayedStock(product.stockQuantity),
    };
  }

  update(id: string, updateProductDto: UpdateProductDto) {
    return this.prisma.product.update({
      where: { id },
      data: updateProductDto,
    });
  }

  remove(id: string) {
    return this.prisma.product.delete({ where: { id } });
  }

  // Regla de Oro 4: Buffer de Inventario
  private getDisplayedStock(realStock: number): number {
    return Math.max(0, realStock - this.BUFFER_QUANTITY);
  }
}
