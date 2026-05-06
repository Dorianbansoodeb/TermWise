import { Schema, model, InferSchemaType, Types } from 'mongoose';

const profileSchema = new Schema(
  {
    userId: { type: Types.ObjectId, ref: 'User', required: true, unique: true },
    schoolName: { type: String, default: '' },
    programName: { type: String, default: '' },
    termType: { type: String, enum: ['school', 'coop'], default: 'school' },
    monthlyBudgetStartDay: { type: Number, default: 1 }
  },
  { timestamps: true }
);

export type ProfileDocument = InferSchemaType<typeof profileSchema>;
export const Profile = model<ProfileDocument>('Profile', profileSchema);
