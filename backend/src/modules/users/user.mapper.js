function mapUser(row) {
  return {
    id: String(row.id),
    name: row.name,
    email: row.email,
    avatarPath: row.avatarPath ?? row.avatar_path ?? null,
    publicKey: row.publicKey ?? row.public_key ?? null,
    fcmToken: row.fcmToken ?? row.fcm_token ?? null,
    createdAt: row.createdAt ?? row.created_at ?? null,
    updatedAt: row.updatedAt ?? row.updated_at ?? null,
  };
}

module.exports = {
  mapUser,
};
