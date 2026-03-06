
import { Controller, Get, Post, Body, Patch, Param, Delete } from '@nestjs/common';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) { }

  @Post()
  create(@Body() createOrderDto: any) {
    return this.ordersService.create(createOrderDto);
  }

  @Get()
  findAll() {
    return this.ordersService.findAll();
  }

  @Get('shopper')
  findForShoppers() {
    return this.ordersService.findForShoppers();
  }

  @Get('driver')
  findForDrivers() {
    return this.ordersService.findForDrivers();
  }

  @Get('driver/available-batches')
  findAvailableBatches() {
    return this.ordersService.findAvailableBatches();
  }

  @Post('driver/accept-batch')
  acceptBatch(@Body() acceptDto: { driverId: string; orderIds: string[] }) {
    return this.ordersService.acceptBatch(acceptDto.driverId, acceptDto.orderIds);
  }

  @Get('driver/completed')
  findCompletedForDrivers() {
    return this.ordersService.findCompletedForDrivers();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ordersService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateOrderDto: any) {
    return this.ordersService.update(id, updateOrderDto);
  }

  @Patch(':id/items/:itemId')
  updateItem(@Param('id') orderId: string, @Param('itemId') itemId: string, @Body() updateData: any) {
    return this.ordersService.updateItem(itemId, updateData);
  }
}
