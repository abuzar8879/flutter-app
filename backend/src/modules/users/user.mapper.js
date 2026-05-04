function mapUser(row) {
  return {
    id: Number(row.id),
    name: row.name,
    email: row.email,
    avatarPath: row.avatar_path,
    publicKey: row.public_key,
    fcmToken: row.fcm_token,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = {
  mapUser,
};
