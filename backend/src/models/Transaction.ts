import { Schema, model, InferSchemaType, Types } from 'mongoose';

const transactionSchema = new Schema(
  {
    userId: { type: Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['income', 'expense'], required: true },
    category: { type: String, required: true },
    description: { type: String, default: '' },
    amount: { type: Number, required: true },
    occurredAt: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

export type TransactionDocument = InferSchemaType<typeof transactionSchema>;
export const Transaction = model<TransactionDocument>('Transaction', transactionSchema);
